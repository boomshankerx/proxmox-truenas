package PVE::Storage::Custom::TrueNAS;
use base qw(PVE::Storage::ZFSPoolPlugin);

use strict;
use warnings;

use PVE::RESTEnvironment qw(log_warn);
use PVE::RPCEnvironment;

# use lib '/root/proxmox-truenas/perl5';
use TrueNAS::Client;
use TrueNAS::Helpers qw(_log _debug);

# Global variable definitions
my $base                      = '/dev/zvol';
my $MAX_LUNS                  = 255;           # Max LUNS per target  the iSCSI server
my $truenas_server_list       = undef;         # API connection HashRef using the IP address of the server
my $truenas_client            = undef;         # Pointer to entry in $truenas_server_list
my $truenas_iscsi_global_list = undef;         # IQN HashRef using the IP address of the server
my $truenas_iscsi_global      = undef;         # Pointer to entry in $truenas_iscsi_global_list
my $dev_prefix                = "/dev/";

# FreeNAS API definitions
my $truenas_product      = undef;
my $truenas_version      = undef;
my $truenas_release_type = "Production";

sub api {
    return 12;
}

sub type {
    return 'truenas';
}

sub plugindata {
    return {
        content                => [ { images => 1 }, { images => 1 } ],
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
        nodes              => { optional => 1 },
        disable            => { optional => 1 },
        portal             => { fixed    => 1 },
        target             => { fixed    => 0 },
        pool               => { fixed    => 0 },
        blocksize          => { fixed    => 1 },
        sparse             => { optional => 1 },
        truenas_user       => { optional => 1 },
        truenas_password   => { optional => 1 },
        truenas_use_ssl    => { optional => 1 },
        truenas_apiv4_host => { optional => 1 },
        truenas_apikey     => { optional => 1 },
        'zfs-base-path'    => { optional => 1 },
    };
}

# TrueNAS

# Check to see what TrueNAS version we are running and set
# the TrueNAS.pm to use the correct API version of TrueNAS
sub truenas_client_init {
    my $scfg    = shift;
    my $timeout = shift || 10;
    my $result  = {};
    my $apihost =
      defined( $scfg->{truenas_apiv4_host} )
      ? $scfg->{truenas_apiv4_host}
      : $scfg->{portal};

    if ( !defined $truenas_server_list->{$apihost} ) {
        $result = truenas_client_connect($scfg);
        _log( "Version: " . $result );
    }
    else {
        $truenas_client->set_target( $scfg->{target} );
        _log("Using existing client", 'debug');
    }

    $truenas_iscsi_global = $truenas_iscsi_global_list->{$apihost} =
      ( !defined( $truenas_iscsi_global_list->{$apihost} ) )
      ? $truenas_client->iscsi_global_config($scfg)
      : $truenas_iscsi_global_list->{$apihost};
    return;
}

#
# Connect to the TrueNAS API service
sub truenas_client_connect {
    my ($scfg) = @_;

    my $apihost =
      defined( $scfg->{truenas_apiv4_host} )
      ? $scfg->{truenas_apiv4_host}
      : $scfg->{portal};

    if ( !defined $truenas_server_list->{$apihost} ) {
        $truenas_server_list->{$apihost} = TrueNAS::Client->new($scfg);
    }
    my $client = $truenas_server_list->{$apihost};
    my $result = $client->request('system.version');
    if ( $client->{has_error} ) {
        truenas_api_log_error();
        die "Unable to connect to the TrueNAS API service at '" . $client->{uri} . "'\n";
        return undef;
    }
    $truenas_client = $truenas_server_list->{$apihost};
    return $result;
}

# Storage implementation
########################

# called during addition of storage (before the new storage config got written)
# die to abort addition if there are (grave) problems
# NOTE: runs in a storage config *locked* context
sub on_add_hook {
    my ( $class, $storeid, $scfg, %param ) = @_;

    if ( !$scfg->{'zfs-base-path'} ) {
        $scfg->{'zfs-base-path'} = $base;
    }
}

sub path {
    my ( $class, $scfg, $volname, $storeid, $snapname ) = @_;

    _log( "Called", 'debug' );

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

sub alloc_image {
    my ( $class, $storeid, $scfg, $vmid, $fmt, $name, $size ) = @_;

    _log( "Called", 'debug' );

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

    _log("Created zvol '$volname' in pool '$scfg->{pool}' with size $size bytes");

    return $volname;
}

sub free_image {
    my ( $class, $storeid, $scfg, $volname, $isBase ) = @_;

    _log("Called");

    my ( $vtype, $name, $vmid ) = $class->parse_volname($volname);

    for ( my $i = 0 ; $i < 6 ; $i++ ) {
        truenas_client_init($scfg);
        my $result = $truenas_client->zfs_zvol_delete("$scfg->{pool}/$name");
        last if $result;
        sleep(1);
    }

    _log("Deleted zvol '$name' from pool '$scfg->{pool}'");

    return undef;
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
    my $snapshot_name = "$scfg->{pool}/$vname\@$snap";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_create($snapshot_name);

    _log("Created snapshot $snapshot_name'");

}

sub volume_snapshot_delete {
    my ( $class, $scfg, $storeid, $volname, $snap, $running ) = @_;

    truenas_client_init($scfg);
    my $object = "$scfg->{pool}/$volname\@$snap";
    my $result = $truenas_client->zfs_snapshot_delete($object);
    if ($result) {
        _log("Deleted snapshot '$snap' for volume '$volname'");
    }

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
    my $snapshot_name = "$scfg->{pool}/$vname\@$snap";

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_snapshot_rollback($snapshot_name);

    _log("Rolled back $volname to snapshot $snapshot_name");

}

sub volume_rollback_is_possible {
    my ( $class, $scfg, $storeid, $volname, $snap, $blockers ) = @_;

    # can't use '-S creation', because zfs list won't reverse the order when the
    # creation time is the same second, breaking at least our tests.
    # my $snapshots = $class->zfs_get_sorted_snapshot_list($scfg, $volname, ['-s', 'creation']);

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

sub volume_resize {
    my ( $class, $scfg, $storeid, $volname, $size, $running ) = @_;

    _log("Called");

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

# list_images DONE

# ZFS operations
################

sub zfs_list_zvol {
    my ($class) = shift;
    my ($scfg)  = shift;

    truenas_client_init($scfg);
    my $result = $truenas_client->zfs_zvol_list();
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

sub zfs_add_lun_mapping_entry {
    my ( $class, $scfg, $volname, $guid ) = @_;

    truenas_client_init($scfg);
    my $result = $truenas_client->iscsi_lun_add( $volname, $guid );

    if ( $truenas_client->{has_error} ) {
        truenas_api_log_error();
        die "Failed to add LUN mapping entry for '$volname': " . $truenas_client->{error_message} . "\n";
    }

    return $result;
}

1;
