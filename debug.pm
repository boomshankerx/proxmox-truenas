#!/usr/bin/env perl

use lib '/root/proxmox-truenas/perl5';
use IO::File;
use Log::Any qw($log);
use Log::Any::Adapter;
use POSIX                qw(ENOENT);
use PVE::RESTEnvironment qw(log_warn);
use PVE::RPCEnvironment;
use PVE::SafeSyslog;
use PVE::Tools qw(run_command);
use TrueNAS::Client;
use TrueNAS::Helpers qw(_log _debug);
use PVE::Storage::Custom::TrueNAS;

use PVE::SafeSyslog;

# DEBUGGING
#######################################################
my $scfg;
$scfg = {
    'truenas_apiv4_host' => '192.168.11.186',
    'truenas_user'       => 'admin',
    'truenas_password'   => 'nimda',
    'truenas_apikey'     => '1-Z7axbKWVM1boVTgZnyZiBnSMkVKs80q6h8qZZGJdP8Qj2dHnp7Y1j2tjOHZwqbIB',
    'portal'             => '192.168.11.186',
    'debug'              => 1,
    'truenas_use_ssl'    => 1,
    'target'             => 'iqn.2005-10.org.freenas.ctl:proxmox',
    'pool'               => 'tank/proxmox',
    'type'               => 'truenas',
    'blocksize'          => '16K',
    'sparse'             => 1,

};

use DateTime;
my $dt = DateTime->now;
print "\n########################################################################\n";
print $dt->strftime("%Y-%m-%d %H:%M:%S") . "\n";
print $scfg->{truenas_apiv4_host};
print "\n########################################################################\n";

sub log_test {
    _log( "This is a debug message",   'debug' );
    _log( "This is an info message",   'info' );
    _log( "This is a warning message", 'warning' );
    _log( "This is an error message",  'error' );
    _debug( "This is a debug message with multiple args", { key => 'value' }, [ 1, 2, 3 ], "string" );
}

sub client_test {
    my $client = TrueNAS::Client->new($scfg);
    print $client->request('system.version') . "\n";
    sleep(60);
    print $client->request('system.info') . "\n";
}

log_test();

# MAIN
# my $client = TrueNAS::Client->new($scfg);
# log_test();
# client_test();

# PVE::Storage::Custom::TrueNAS->path($scfg, 'vm-100-disk-0', );
# PVE::Storage::Custom::TrueNAS->qemu_blockdev_options($scfg, '', 'vm-100-disk-0');

# _debug(PVE::Storage::TrueNAS->list_images("", $scfg, 100, undef, undef));
# _debug( PVE::Storage::Custom::TrueNAS->alloc_image( '', $scfg, '100', 'raw', 'vm-100-disk-10', 1048576, 'zfs' ) );
# _debug( PVE::Storage::Custom::TrueNAS->volume_resize( $scfg, undef, 'vm-100-disk-10', 2097152 * 1024 ) );
# _debug( PVE::Storage::Custom::TrueNAS->free_image( '', $scfg, 'vm-100-disk-10' ) );
# _debug( PVE::Storage::Custom::TrueNAS->status( '', $scfg,  ) );
# _debug( PVE::Storage::Custom::TrueNAS->list_images( '', $scfg, undef, undef, undef ) );

# _debug( PVE::Storage::Custom::TrueNAS->volume_snapshot_info( $scfg, '', 'vm-100-disk-0' ) );
# _debug( PVE::Storage::Custom::TrueNAS->volume_snapshot_delete( $scfg, '', 'vm-100-disk-0', 'test' ) );

#  my ($class, $storeid, $scfg, $vmid, $fmt, $add_fmt_suffix) = @_;
# _debug(PVE::Storage::TrueNAS->find_free_diskname('', $scfg, '100', 'raw', 0));
