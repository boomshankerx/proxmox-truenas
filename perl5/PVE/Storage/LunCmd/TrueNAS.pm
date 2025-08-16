package PVE::Storage::LunCmd::TrueNAS;
use strict;
use warnings;

use Data::Dumper;
use JSON;
use Log::Any qw($log);
use Log::Any::Adapter;
use PVE::SafeSyslog;
use Scalar::Util qw(reftype);
use TrueNAS::Client;

use TrueNAS::Helpers qw(_log _debug);

# Global variable definitions
my $MAX_LUNS                  = 255;       # Max LUNS per target  the iSCSI server
my $truenas_server_list       = undef;     # API connection HashRef using the IP address of the server
my $truenas_client            = undef;     # Pointer to entry in $truenas_server_list
my $truenas_iscsi_global_list = undef;     # IQN HashRef using the IP address of the server
my $truenas_iscsi_global      = undef;     # Pointer to entry in $truenas_iscsi_global_list
my $dev_prefix                = "/dev/";

# FreeNAS API definitions
my $truenas_product      = undef;
my $truenas_version      = undef;
my $truenas_release_type = "Production";

#
# Return base path for zvols
#
sub get_base {
    return '/dev/zvol';
}

#
# Subroutine called from ZFSPlugin.pm
#
sub run_lun_command {
    my ( $scfg, $timeout, $method, @params ) = @_;

    truenas_client_init($scfg);

    return _add_view( $scfg, $timeout, @params )          if ( $method eq "add_lu" );
    return _create_lu( $scfg, $timeout, @params )         if ( $method =~ /^(create|import)_lu$/ );
    return _delete_lu( $scfg, $timeout, @params )         if ( $method eq "delete_lu" );
    return _list_extent( $scfg, $timeout, @params )       if ( $method eq "list_extent" );
    return _list_lu( $scfg, $timeout, 'name', @params )   if ( $method eq "list_lu" );
    return _list_view( $scfg, $timeout, @params )         if ( $method eq "list_view" );
    return _modify_lu( $scfg, $timeout, @params )         if ( $method eq "modify_lu" );
    return _snapshot_create( $scfg, $timeout, @params )   if ( $method eq "snapshot" );
    return _snapshot_delete( $scfg, $timeout, @params )   if ( $method eq "destroy" );
    return _snapshot_rollback( $scfg, $timeout, @params ) if ( $method eq "rollback" );
    return ''                                             if ( $method eq "add_view" );

    _log("Unknown method '$method' called");

    return undef;
}

#
#
#
sub _add_view {
    return '';
}

#
#
#
sub _create_lu {
    my ( $scfg, $timeout, @params ) = @_;
    my $lun_path = $params[0];

    _log($lun_path);

    my $result = $truenas_client->iscsi_lun_create($lun_path);
    
    if (!$result) {
        die "Unable to create lun $lun_path";
    }

    return "";
}

#
# Delete a lun
#
sub _delete_lu {
    my ( $scfg, $timeout, @params ) = @_;
    my $lun_path = $params[0];

    $lun_path =~ s/^\Q$dev_prefix//;
    my $result = $truenas_client->iscsi_lun_delete($lun_path);
    if (!$result) {
        _log("Unable to delete lun $lun_path");
    }

    return "";
}


#
#
#
sub _list_extent {
    my ( $scfg, $timeout, @params ) = @_;

    return _list_lu( $scfg, $timeout, "naa", @params );
}

#
# Returns:
#
sub _list_lu {
    my ( $scfg, $timeout, $search_field, @params ) = @_;
    my $object = $params[0];    # search value
    my $result = undef;

    $object =~ s/^\Q$dev_prefix//;

    my $lun = $truenas_client->iscsi_lun_get($object);
    if ( defined($lun) ) {
        if ( defined($search_field) ) {
            if ( $search_field eq "name" ) {
                $result = $dev_prefix . $lun->{path};
            }
            elsif ( $search_field eq "lunid" ) {
                $result = $lun->{lunid};
            }
            elsif ( $search_field eq "naa" ) {
                $result = $lun->{naa};
            }
        }
        _log("$object with key '$search_field' found : $result");
    }
    else {
        _log("$object with key '$search_field' was not found");
    }

    return $result;
}

#
#
#
sub _list_view {
    my ( $scfg, $timeout, @params ) = @_;

    return _list_lu( $scfg, $timeout, "lunid", @params );
}

#
# a modify_lu occur by example on a zvol resize. we just need to destroy and recreate the lun with the same zvol.
# Be careful, the first param is the new size of the zvol, we must shift params
#
sub _modify_lu {
    my ( $scfg, $timeout, @params ) = @_;
    shift(@params);

    _delete_lu( $scfg, $timeout, @params );
    return _create_lu( $scfg, $timeout, @params );
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

# Check to see what TrueNAS version we are running and set
# the TrueNAS.pm to use the correct API version of TrueNAS
sub truenas_client_init {
    my ( $scfg, $timeout ) = @_;
    my $result = {};
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
        _log("Websocket Client already initialized");
    }

    $truenas_iscsi_global = $truenas_iscsi_global_list->{$apihost} =
      ( !defined( $truenas_iscsi_global_list->{$apihost} ) )
      ? $truenas_client->iscsi_global_config($scfg)
      : $truenas_iscsi_global_list->{$apihost};
    return;
}

# Writes the Response and Content to SysLog
#
sub truenas_api_log_error {
    my $conn = shift || $truenas_client;
    _log( $conn->{error}, "error" );
    return 1;
}

# HELPER FUNCTIONS

# Simple TrueNAS API query builder. Only handles '='
sub _build_query {
    my $params = shift || {};
    my $result = [];

    foreach my $key ( keys %$params ) {
        my $query = [];
        my $value = $params->{$key};
        $value += 0 if ( $value =~ /^\d+$/ );
        push( @$query,  $key );
        push( @$query,  '=' );
        push( @$query,  $value );
        push( @$result, $query );
    }
    return $result;
}

1;
