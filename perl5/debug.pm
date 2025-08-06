#!/usr/bin/env perl
use lib '/root/proxmox-truenas/perl5';
use PVE::Storage::LunCmd::TrueNAS;
use TrueNAS::Client;
use Log::Any qw($log);
use Log::Any::Adapter;
use Data::Dumper;
use JSON;
use JSON::RPC::Common::Marshal::Text;
use Scalar::Util qw(reftype);

use PVE::SafeSyslog;

Log::Any::Adapter->set( 'Stdout', log_level => 'info' );
Log::Any::Adapter->set( 'Stdout', log_level => 'debug' );

# DEBUGGING
#######################################################
my $cfg;
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

# $scfg = {
#     'truenas_apiv4_host' => '192.168.11.172',
#     'truenas_user'       => 'admin',
#     'truenas_password'   => 'nimda',
#     'truenas_apikey'     => '1-dDmyNOXQKkjUn4bpr5T5I9lJeYYLvRMN5D5rq8n1cgGxtBShCLkN6Fk3xu6hCIzU',
#     'portal'             => '192.168.11.158',
#     'debug'              => 1,
#     'truenas_use_ssl'    => 1,
#     'target'             => 'iqn.2005-01.com.techgsolutions:proxmox',
#     'pool'               => 'tank',

# };

# $scfg = {
#     'truenas_apiv4_host' => '192.168.11.177',
#     'truenas_user'       => 'admin',
#     'truenas_password'   => 'nimda',
#     'truenas_apikey'     => '1-1K8wWbWDUlhZ3TmknBas6dlRq2C2Bgpc6i6FYKPja4oabygCMDakXKOZWEEv9Yhm',
#     'portal'             => '192.168.11.158',
#     'debug'              => 1,
#     'truenas_use_ssl'    => 1,
#     'target'             => 'iqn.2005-01.com.techgsolutions:proxmox',
#     'pool'               => 'tank',

# };

use DateTime;
my $dt = DateTime->now;
print "\n########################################################################\n";
print $dt->strftime("%Y-%m-%d %H:%M:%S") . "\n";
print $scfg->{truenas_apiv4_host} . "\n";
print "\n########################################################################\n";

sub simple_check {
    my $client = TrueNAS::Client->new($scfg);
    print $client->request('system.version');
    sleep(60);
    print $client->zvol_list();
}

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

# Logging Helper
sub _log {
    my $message = shift;
    my $level   = shift || 'info';

    print reftype($message) . "\n";

    if ( reftype($message) eq 'HASH' || reftype($message) eq 'ARRAY' ) {
        $message = Dumper($message);
    }

    my $syslog_map = {
        'debug' => 'debug',
        'info'  => 'info',
        'warn'  => 'warning',
        'error' => 'err',
    };

    my $level_uc = uc($level);
    my $src      = ( caller(1) )[3];
    $src     = ( split( /::/, $src ) )[-1];
    $message = "[$level_uc]: TrueNAS: $src : $message";
    $log->$level($message);
    ## FILTER DEBUG LATER
    syslog( "$syslog_map->{$level}", $message );
}
simple_check();
# api_check();
