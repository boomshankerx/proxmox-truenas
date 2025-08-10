package PVE::Storage::TrueNAS;

use strict;
use warnings;

use base qw(PVE::Storage::ZFSPoolPlugin);
use IO::File;
use Log::Any qw($log);
use Log::Any::Adapter;
use POSIX qw(ENOENT);
use PVE::RESTEnvironment qw(log_warn);
use PVE::RPCEnvironment;
use PVE::SafeSyslog;
use PVE::Tools qw(run_command);
use lib '/root/proxmox-truenas-plugin/perl5';
use TrueNAS::Client;
use TrueNAS::Helpers qw(_log);

my $base_path = '/dev/zvol';

sub type {
    return 'truenas';
}

sub plugindata {
    return {
        content => [{ images => 1 }, { images => 1 }],
        'sensitive-properties' => {},
    };
}

sub properties {
        truenas_user => {
            description => "TrueNAS API Username",
            type => 'string',
        },
        truenas_password => {
            description => "TrueNAS API Password",
            type => 'string',
        },
        truenas_use_ssl => {
            description => "TrueNAS API access via SSL",
            type => 'boolean',
        },
        truenas_apiv4_host => {
            description => "TrueNAS API Host",
            type => 'string',
        },
        truenas_apikey => {
            description => "TrueNAS API Key",
            type => 'string',
        },
}

sub options {
    return {
        nodes => { optional => 1 },
        disable => { optional => 1 },
        portal => { fixed => 1 },
        target => { fixed => 0 },
        pool => { fixed => 0 },
        blocksize => { fixed => 1 },
        sparse => { optional => 1 },
        truenas_user => { optional => 1 },
        truenas_password => { optional => 1 },
        truenas_use_ssl => { optional => 1 },
        truenas_apiv4_host => { optional => 1 },
        truenas_apikey => { optional => 1 },
        'zfs-base-path' => { optional => 1 },
    };
}

# Storage implementation

# called during addition of storage (before the new storage config got written)
# die to abort addition if there are (grave) problems
# NOTE: runs in a storage config *locked* context
sub on_add_hook {
    my ($class, $storeid, $scfg, %param) = @_;

    if (!$scfg->{'zfs-base-path'}) {
        $scfg->{'zfs-base-path'} = $base_path;
    }
}

sub path {
    my ($class, $scfg, $volname, $storeid, $snapname) = @_;

    die "direct access to snapshots not implemented"
        if defined($snapname);

    my ($vtype, $name, $vmid) = $class->parse_volname($volname);

    my $target = $scfg->{target};
    my $portal = $scfg->{portal};

    #TODO Tie these to TrueNAS Client
    # my $guid = $class->zfs_get_lu_name($scfg, $name);
    # my $lun = $class->zfs_get_lun_number($scfg, $guid);
    my $lun = 0;

    my $path = "iscsi://$portal/$target/$lun";

    _log("$path, vmid: $vmid, vtype: $vtype", 'debug');

    return ($path, $vmid, $vtype);
}

1;
