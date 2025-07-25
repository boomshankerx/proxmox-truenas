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

# Logging
Log::Any::Adapter->set( 'Stdout', log_level => 'info' );
my $debug = 1;

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

    _log(" $timeout : $method : @params");

    truenas_api_check($scfg);

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
    if ($result) {
        _log( $lun_path . " Success" );
    }
    else {
        die "Unable to create lun $lun_path";
    }

    return "";
}

# #
# #
# #
# sub _create_lu {
#     my ( $scfg, $timeout, @params ) = @_;
#     my $lun_path = $params[0];

#     _log($lun_path);

#     my $lun_id = truenas_iscsi_targetextent_nextid($scfg);

#     die "Maximum number of LUNs per target is $MAX_LUNS"
#       if scalar $lun_id >= $MAX_LUNS;

#     die "$params[0]: LUN $lun_path exists"
#       if defined( _list_lu( $scfg, $timeout, "path", @params ) );

#     my $target_id = truenas_iscsi_target_id($scfg);
#     die "Unable to find the target id for $scfg->{target}"
#       if !defined($target_id);

#     # Create the extent
#     my $extent = truenas_iscsi_extent_create( $scfg, $lun_path );

#     # Associate the new extent to the target
#     my $link = truenas_iscsi_targetextent_create( $scfg, $target_id, $extent->{'id'}, $lun_id );

#     if ( defined($link) ) {
#         _log( "$lun_path : T" . $target_id . ":E" . $extent->{'id'} . ":L" . $lun_id );
#     }
#     else {
#         die "Unable to create lun $lun_path";
#     }

#     return "";
# }

#
# Delete a lun
#
sub _delete_lu {
    my ( $scfg, $timeout, @params ) = @_;
    my $lun_path = $params[0];

    _log("$lun_path");

    $lun_path =~ s/^\Q$dev_prefix//;
    my $result = $truenas_client->iscsi_lun_delete($lun_path);
    if ($result) {
        _log( $lun_path . " Deleted" );
    }
    else {
        _log("Unable to delete lun $lun_path");
    }

    return "";
}

#
# Delete a lun
#
# sub _delete_lu {
#     my ( $scfg, $timeout, @params ) = @_;
#     my $lun_path = $params[0];

#     _log("$lun_path");

#     $lun_path =~ s/^\Q$dev_prefix//;
#     my $lun = truenas_iscsi_extent_get( $scfg, { path => $lun_path } );

#     if ( !defined($lun) ) {
#         die "Unable to find the lun $lun_path for $scfg->{target}";
#     }

#     # Remove the extent
#     my $remove_extent = truenas_iscsi_extent_delete( $scfg, $lun->{id} );

#     if ( $remove_extent == 1 ) {
#         _log( $lun_path . " Deleted" );
#     }
#     else {
#         die "Unable to delete lun $lun_path";
#     }

#     return "";
# }

#
#
#
sub _list_extent {
    my ( $scfg, $timeout, @params ) = @_;

    _log("Called");

    return _list_lu( $scfg, $timeout, "naa", @params );
}

#
# Returns:
#
sub _list_lu {
    my ( $scfg, $timeout, $search_field, @params ) = @_;
    my $object = $params[0];    # search value
    my $result = undef;

    _log("$search_field, $object");

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

    _log("Called");

    return _list_lu( $scfg, $timeout, "lunid", @params );
}

#
# a modify_lu occur by example on a zvol resize. we just need to destroy and recreate the lun with the same zvol.
# Be careful, the first param is the new size of the zvol, we must shift params
#
sub _modify_lu {
    my ( $scfg, $timeout, @params ) = @_;
    shift(@params);

    _log("Called");

    _delete_lu( $scfg, $timeout, @params );
    return _create_lu( $scfg, $timeout, @params );
}

#
# Connect to the TrueNAS API service
sub truenas_api_connect {
    my ($scfg) = @_;

    _log("Called");

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
sub truenas_api_check {
    my ( $scfg, $timeout ) = @_;
    my $result = {};
    my $apihost =
      defined( $scfg->{truenas_apiv4_host} )
      ? $scfg->{truenas_apiv4_host}
      : $scfg->{portal};

    _log("Called");

    if ( !defined $truenas_server_list->{$apihost} ) {
        $result = truenas_api_connect($scfg);
        _log( "Version: " . $result );
    }
    else {
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

# Logging Helper
sub _log {
    my $message = shift;
    my $level   = shift || 'info';

    if ( $level eq 'debug' && !$debug )
    {
        return;
    }

    if ( defined reftype($message) ) {
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
    syslog( "$syslog_map->{$level}", $message );
}

1;
