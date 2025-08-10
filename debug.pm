#!/usr/bin/env perl

use lib '/root/proxmox-truenas/perl5';
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
use PVE::Storage::TrueNAS;

use PVE::SafeSyslog;

Log::Any::Adapter->set( 'Stdout', log_level => 'info' );
Log::Any::Adapter->set( 'Stdout', log_level => 'debug' );

# DEBUGGING
#######################################################
my $scfg;
$scfg = {
    'truenas_apiv4_host' => '192.168.11.158',
    'truenas_user'       => 'admin',
    'truenas_password'   => 'nimda',
    'truenas_apikey'     => '3-97WToGxP6T1d66AVLoRqqKWoxpdaoLK73Simau8wW5uMHvMlDQu7ptid507Je4WR',
    'portal'             => '192.168.11.158',
    'debug'              => 1,
    'truenas_use_ssl'    => 1,
    'target'             => 'iqn.2005-01.com.techgsolutions:proxmox',
    'pool'               => 'tank/proxmox',

};

use DateTime;
my $dt = DateTime->now;
print "\n########################################################################\n";
print $dt->strftime("%Y-%m-%d %H:%M:%S") . "\n";
print $scfg->{truenas_apiv4_host} . "\n";
print "\n########################################################################\n";


sub api_check {
    ### API TESTING
    print Dumper($scfg);
    PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
    print "\n\n########################################################################\n\n";
    PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_view', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
    print "\n\n########################################################################\n\n";
    PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_extent', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
    print "\n\n########################################################################\n\n";
    PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'delete_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
    print "\n\n########################################################################\n\n";
    PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'create_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );

}

sub log_test {
    _log( "This is a debug message", 'debug' );
    _log( "This is an info message", 'info' );
    _log( "This is a warning message", 'warning' );
    _log( "This is an error message", 'error' );
}

sub client_test {
    my $client = TrueNAS::Client->new($scfg);
    print $client->request('system.version'). "\n";
    print $client->request('system.info') . "\n";
}

# MAIN

my $client = TrueNAS::Client->new($scfg);

PVE::Storage::TrueNAS->path($scfg, 'vm-100-disk-0');
PVE::Storage::TrueNAS->path($scfg, 'subvol-100-disk-0');
PVE::Storage::TrueNAS->path($scfg, 'base-100-disk-0');
