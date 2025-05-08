#!/usr/bin/env perl
use lib '/root/freenas-proxmox/perl5';
use PVE::Storage::LunCmd::TrueNAS;
use TrueNAS::Client;
use AnyEvent;
use Log::Any qw($log);
use Log::Any::Adapter;
use Data::Dumper;
use JSON;
use JSON::RPC::Common::Marshal::Text;

# DEBUGGING
#######################################################
my $scfg = {
    'freenas_apiv4_host' => '192.168.11.158',
    'freenas_user'       => 'truenas_admin',
    'freenas_password'   => 'nimda',
    'portal'             => '192.168.11.158',
    'debug'              => 1,
    'freenas_use_ssl'    => 0,
    'target'             => 'iqn.2005-01.com.techgsolutions:proxmox',
    'pool'               => 'tank',

};

Log::Any::Adapter->set( 'Stdout', log_level => 'info' );
# Log::Any::Adapter->set( 'Stdout', log_level => 'debug' );

use DateTime;
my $dt = DateTime->now;
print "\n########################################################################\n";
print $dt->strftime("%Y-%m-%d %H:%M:%S");
print "\n########################################################################\n";

# my $client = TrueNAS::Client->new($scfg);
# my $result = $client->request('system.version');

#### API TESTING
PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
print "\n\n########################################################################\n\n";
PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_view', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
print "\n\n########################################################################\n\n";
PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'list_extent', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
print "\n\n########################################################################\n\n";
PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'delete_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
print "\n\n########################################################################\n\n";
PVE::Storage::LunCmd::TrueNAS::run_lun_command( $scfg, 10, 'create_lu', '/dev/zvol/tank/proxmox/vm-90000-disk-0' );
