package PVE::Storage::Custom::TrueNASPlugin;
use base qw(PVE::Storage::ZFSPoolPlugin);

use strict;
use warnings;

use PVE::RESTEnvironment qw(log_warn);
use PVE::RPCEnvironment;

use TrueNAS::Client;
use TrueNAS::Helpers qw(_log _debug);

# Global variable definitions
my $base                = '/dev/zvol';
my $dev_prefix          = "/dev/";
my $MAX_LUNS            = 255;           # Max LUNS per target  the iSCSI server
my $truenas_client      = undef;         # Pointer to entry in $truenas_server_list
my $truenas_server_list = undef;         # API connection HashRef using the IP address of the server

# my $truenas_iscsi_global      = undef;         # Pointer to entry in $truenas_iscsi_global_list
# my $truenas_iscsi_global_list = undef;         # IQN HashRef using the IP address of the server

sub api {
    return 12;
}

sub type {
    return 'truenas';
}

sub plugindata {
    return {
        content                => [ { images => 1 }, { images => 1 } ],
        format                 => [ { raw    => 1 }, 'raw' ],
        'sensitive-properties' => {},
    };
}

sub properties {
    return {
        truenas_user => {
            description => "TrueNAS API Username",
            type        => 'string',
        },
        truenas_password => {
            description => "TrueNAS API Password",
            type        => 'string',
        },
        truenas_use_ssl => {
            description => "TrueNAS API access via SSL",
            type        => 'boolean',
        },
        truenas_apiv4_host => {
            description => "TrueNAS API Host",
            type        => 'string',
        },
        truenas_apikey => {
            description => "TrueNAS API Key",
            type        => 'string',
        },
    };
}

sub options {
    return {
        blocksize          => { fixed    => 1 },
        content            => { optional => 1 },
        disable            => { optional => 1 },
        nodes              => { optional => 1 },
        pool               => { fixed    => 0 },
        portal             => { fixed    => 1 },
        shared             => { fixed    => 1 },
        sparse             => { optional => 1 },
        target             => { fixed    => 0 },
        truenas_apikey     => { optional => 1 },
        truenas_apiv4_host => { optional => 1 },
        truenas_password   => { optional => 1 },
        truenas_use_ssl    => { optional => 1 },
        truenas_user       => { optional => 1 },
        'zfs-base-path'    => { optional => 1 },
    };
}

# --- TrueNAS --------------------------------------------------------------------------------

# Initialize TrueNAS API client
sub truenas_client_init {
    my $scfg    = shift;
    my $timeout = shift || 10;

    my $apihost = $scfg->{truenas_apiv4_host};

    # Check if a client exists for host
    if ( !defined $truenas_server_list->{$apihost} ) {

        _log( "Client New: ($apihost)", 'debug' );

        $truenas_client = TrueNAS::Client->new($scfg);
        $truenas_server_list->{$apihost} = $truenas_client;

        my $result = $truenas_client->request('system.version');
        if ( !$result ) {
            die "Unable to connect to the TrueNAS API service at '" . $truenas_client->{uri} . "'\n";
        }
        _log( "Version: " . $result );

    }
    else {
        $truenas_client = $truenas_server_list->{$apihost};
        $truenas_client->set_target( $scfg->{target} );

        _log( "Client: ($apihost)", 'debug' );
    }

    # $truenas_iscsi_global = $truenas_iscsi_global_list->{$apihost} =
    #   ( !defined( $truenas_iscsi_global_list->{$apihost} ) )
    #   ? $truenas_client->iscsi_global_config($scfg)
    #   : $truenas_iscsi_global_list->{$apihost};

    return;
}

# --- Storage implementation --------------------------------------------------------------

sub alloc_image {
    my ( $class, $storeid, $scfg, $vmid, $fmt, $name, $size ) = @_;

    die "unsupported format '$fmt'" if $fmt ne 'raw';

    die "illegal name '$name' - should be 'vm-$vmid-*'\n"
      if $name && $name !~ m/^vm-$vmid-/;

    my $volname = $name;

    $volname = $class->find_free_diskname( $storeid, $scfg, $vmid, $fmt )
      if !$volname;
    $size = zfs_align_size($size);

    # Create zvol
    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_create( "$scfg->{pool}/$volname", $size, $scfg->{blocksize}, $scfg->{sparse} );
    if ($result) {
        $truenas_client->iscsi_lun_create("$base/$scfg->{pool}/$volname");
    }

    return $volname;
}

sub create_base {
    my ( $class, $storeid, $scfg, $volname ) = @_;

    _log( "Called", 'debug' );

    my $snap = '__base__';

    my ( $vtype, $name, $vmid, $basename, $basevmid, $isBase ) = $class->parse_volname($volname);

    die "create_base not possible with base image\n" if $isBase;

    my $newname = $name;
    $newname =~ s/^vm-/base-/;

    my $newvolname = $basename ? "$basename/$newname" : "$newname";

    truenas_client_init($scfg);
    my $result = $truenas_client->iscsi_lun_delete("$base/$scfg->{pool}/$name");

    $result = $truenas_client->zfs_zvol_rename( "$scfg->{pool}/$name", "$scfg->{pool}/$newname" );

    $result = $truenas_client->iscsi_lun_create("$base/$scfg->{pool}/$newname");

    $class->volume_snapshot( $scfg, $storeid, $newname, $snap );

    return $newvolname;
}

sub clone_image {
    my ( $class, $scfg, $storeid, $volname, $vmid, $snap ) = @_;

    $snap ||= '__base__';

    my ( $vtype, $basename, $basevmid, undef, undef, $isBase, $format ) = $class->parse_volname($volname);

    die "clone_image only works on base images\n" if !$isBase;

    # get ZFS dataset name from PVE volname
    my $name = $class->find_free_diskname( $storeid, $scfg, $vmid, $format );
    my ( undef, $clonedname ) = $class->parse_volname($name);

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_clone( "$scfg->{pool}/$basename", "$scfg->{pool}/$name", $snap );

    if ($result) {
        $truenas_client->iscsi_lun_create("$base/$scfg->{pool}/$clonedname");
    }

    return $name;
}

sub free_image {
    my ( $class, $storeid, $scfg, $volname, $isBase ) = @_;

    my ( $vtype, $name, $vmid ) = $class->parse_volname($volname);

    truenas_client_init($scfg);
    $truenas_client->iscsi_lun_delete("$base/$scfg->{pool}/$name");
    for ( my $i = 1 ; $i <= 5 ; $i++ ) {
        my $result = $truenas_client->zfs_zvol_delete("$scfg->{pool}/$name");
        last if $result;
        _log( "Retrying zvol delete in " . ( $i * 5 ) . " seconds", 'info' );
        sleep( $i * 5 );
    }
    return undef;
}

# called during addition of storage (before the new storage config got written)
# die to abort addition if there are (grave) problems
# NOTE: runs in a storage config *locked* context
sub on_add_hook {
    my ( $class, $storeid, $scfg, %sensitive ) = @_;

    $scfg->{shared} = 1;
    if ( !$scfg->{'zfs-base-path'} ) {
        $scfg->{'zfs-base-path'} = $base;
    }
}

sub path {
    my ( $class, $scfg, $volname, $storeid, $snapname ) = @_;

    die "direct access to snapshots not implemented"
      if defined($snapname);

    my ( $vtype, $name, $vmid ) = $class->parse_volname($volname);

    my $target = $scfg->{target};
    my $portal = $scfg->{portal};
    my $pool   = $scfg->{pool};
    my $object = "zvol/$pool/$name";

    truenas_client_init($scfg);
    my $extent = $truenas_client->iscsi_lun_get($object);
    my $lun    = $extent->{lunid};

    my $path = "iscsi://$portal/$target/$lun";

    _log( "$path, vmid: $vmid, vtype: $vtype", 'debug' );

    return ( $path, $vmid, $vtype );
}

sub rename_volume {
    my ( $class, $scfg, $storeid, $source_volname, $target_vmid, $target_volname ) = @_;

    _log( "Called", 'debug' );

    my ( undef, $source_image, $source_vmid, $base_name, $base_vmid, undef, $format, ) = $class->parse_volname($source_volname);
    $target_volname = $class->find_free_diskname( $storeid, $scfg, $target_vmid, $format )
      if !$target_volname;

    my $pool           = $scfg->{pool};
    my $source_zfspath = "${pool}/${source_image}";
    my $target_zfspath = "${pool}/${target_volname}";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_rename( $source_zfspath, $target_zfspath );

    $base_name = $base_name ? "${base_name}/" : '';

    return "${storeid}:${base_name}${target_volname}";
}

sub qemu_blockdev_options {
    my ( $class, $scfg, $storeid, $volname, $machine_version, $options ) = @_;

    die "direct access to snapshots not implemented\n"
      if $options->{'snapshot-name'};

    my $name   = ( $class->parse_volname($volname) )[1];
    my $object = "zvol/$scfg->{pool}/$name";

    truenas_client_init($scfg);
    my $extent = $truenas_client->iscsi_lun_get($object);
    my $lun    = $extent->{lunid};

    return {
        driver    => 'iscsi',
        transport => 'tcp',
        portal    => "$scfg->{portal}",
        target    => "$scfg->{target}",
        lun       => int($lun),
    };
}

sub volume_has_feature {
    my ( $class, $scfg, $feature, $storeid, $volname, $snapname, $running ) = @_;

    my $features = {
        clone    => { base    => 1 },
        copy     => { base    => 1, current => 1 },
        rename   => { current => 1 },
        snapshot => { current => 1, snap => 1 },
        template => { current => 1 },
    };

    my ( $vtype, $name, $vmid, $basename, $basevmid, $isBase ) = $class->parse_volname($volname);

    my $key = undef;

    if ($snapname) {
        $key = 'snap';
    }
    else {
        $key = $isBase ? 'base' : 'current';
    }

    return 1 if $features->{$feature}->{$key};

    return undef;
}

sub volume_snapshot {
    my ( $class, $scfg, $storeid, $volname, $snap ) = @_;

    my ( undef, $vname, undef, undef, undef, undef, $format ) = $class->parse_volname($volname);
    my $snapshot = "$scfg->{pool}/$vname\@$snap";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_create($snapshot);

}

sub volume_snapshot_delete {
    my ( $class, $scfg, $storeid, $volname, $snap, $running ) = @_;

    truenas_client_init($scfg);
    my $object = "$scfg->{pool}/$volname\@$snap";
    my $result = $truenas_client->zfs_snapshot_delete($object);

}

sub volume_snapshot_info {

    my ( $class, $scfg, $storeid, $volname ) = @_;

    my $vname = ( $class->parse_volname($volname) )[1];
    my $zvol  = "$scfg->{pool}/$vname";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_list($zvol);

    my $info = {};
    for my $snap ( @{$result} ) {
        my $name     = $snap->{name};
        my $guid     = $snap->{properties}{guid}{value};
        my $creation = $snap->{properties}{creation}{rawvalue};
        $info->{$name} = {
            id        => $guid,
            timestamp => $creation,
        };

    }

    return $info;
}

sub volume_snapshot_rollback {

    my ( $class, $scfg, $storeid, $volname, $snap ) = @_;

    my ( undef, $vname, undef, undef, undef, undef, $format ) = $class->parse_volname($volname);
    my $snapshot = "$scfg->{pool}/$vname\@$snap";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_rollback($snapshot);

}

sub volume_rollback_is_possible {
    my ( $class, $scfg, $storeid, $volname, $snap, $blockers ) = @_;

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_list("$scfg->{pool}/$volname");

    my $found;
    $blockers //= [];    # not guaranteed to be set by caller
    for my $snapshot (@$result) {
        if ( $snapshot->{snapshot_name} eq $snap ) {
            $found = 1;
        }
        elsif ($found) {
            push $blockers->@*, $snapshot;
        }
    }

    my $volid = "${storeid}:${volname}";

    die "can't rollback, snapshot '$snap' does not exist on '$volid'\n"
      if !$found;

    die "can't rollback, '$snap' is not most recent snapshot on '$volid'\n"
      if scalar( $blockers->@* ) > 0;

    _log("Rollback to snapshot '$snap' is possible for '$volid'");

    return 1;

}

sub volume_size_info {
    my ( $class, $scfg, $storeid, $volname, $timeout ) = @_;

    my ( undef, $vname, undef, $parent, undef, undef, $format ) = $class->parse_volname($volname);

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_get("$scfg->{pool}/$vname");

    my $size = $result->{volsize}{rawvalue}       || 0;
    my $used = $result->{usedbydataset}{rawvalue} || 0;

    if ( $size =~ /^(\d+)$/ ) {
        return wantarray ? ( $1, $format, $used, $parent ) : $1;
    }

    die "Could not get zfs volume size\n";
}

sub volume_resize {
    my ( $class, $scfg, $storeid, $volname, $size, $running ) = @_;

    my ( undef, $vname, undef, undef, undef, undef, $format ) = $class->parse_volname($volname);

    # Resize zvol
    my $new_size = zfs_align_size( int( $size / 1024 ) );
    my $attr     = $format eq 'subvol' ? 'refquota' : 'volsize';

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_resize( "$scfg->{pool}/$vname", $new_size, $attr );

    _log( "Resized $volname to $new_size bytes", 'info' );

    return $new_size;
}

sub status {
    my ( $class, $storeid, $scfg, $cache ) = @_;

    my $pool = ( split( "/", $scfg->{pool} ) )[0];

    my $active    = 0;
    my $allocated = 0;
    my $free      = 0;
    my $total     = 0;

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zpool_get($pool);
    if ($result) {
        $active    = 1;
        $allocated = $result->{allocated};
        $free      = $result->{free};
        $total     = $result->{size};
    }

    _log( "Stus: total=$total, free=$free, allocated=$allocated, active=$active", 'debug' );

    return ( $total, $free, $allocated, $active );

}

sub storage_can_replicate {
    my ( $class, $scfg, $storeid, $format ) = @_;

    return 0;
}

sub activate_storage {
    my ( $class, $storeid, $scfg, $cache ) = @_;

    return 1;
}

sub deactivate_storage {
    my ( $class, $storeid, $scfg, $cache ) = @_;

    return 1;
}

sub activate_volume {
    my ( $class, $storeid, $scfg, $volname, $snapname, $cache ) = @_;

    die "unable to activate snapshot from remote zfs storage" if $snapname;

    return 1;
}

sub deactivate_volume {
    my ( $class, $storeid, $scfg, $volname, $snapname, $cache ) = @_;

    die "unable to deactivate snapshot from remote zfs storage" if $snapname;

    return 1;
}

# --- ZFS operations --------------------------------------------------------------

sub zfs_list_zvol {
    my ($class) = shift;
    my ($scfg)  = shift;

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_list( $scfg->{pool} );
    my $zvols  = PVE::Storage::ZFSPoolPlugin::zfs_parse_zvol_list( $result, $scfg->{pool} );
    return {} if !$zvols;

    my $list = {};
    foreach my $zvol (@$zvols) {
        my $name   = $zvol->{name};
        my $parent = $zvol->{origin};
        if ( $zvol->{origin} && $zvol->{origin} =~ m/^$scfg->{pool}\/(\S+)$/ ) {
            $parent = $1;
        }

        $list->{$name} = {
            name   => $name,
            size   => $zvol->{size},
            parent => $parent,
            format => $zvol->{format},
            vmid   => $zvol->{owner},
        };
    }

    return $list;

}

sub zfs_align_size {
    my ($size) = @_;

    # always align size to 1M as workaround until
    # https://github.com/zfsonlinux/zfs/issues/8541 is solved
    my $padding = ( 1024 - $size % 1024 ) % 1024;
    $size = ( $size + $padding ) * 1024;    # convert to Bytes
    return $size;

}

1;
