package TrueNAS::Client;
use strict;
use warnings;

use IO::Socket::IP;
use IO::Socket::SSL;
use JSON::RPC::Common::Marshal::Text;
use JSON::RPC::Common::Procedure::Call;
use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Client;

use Carp qw(croak);
use Data::Dumper;
use Errno qw(EINTR);
use JSON;
use PVE::SafeSyslog;
use Scalar::Util     qw(reftype);
use TrueNAS::Helpers qw(_log _debug);

sub new {
    my ( $class, $scfg ) = @_;

    _log( $scfg, 'debug' );

    my $self = {
        host     => $scfg->{truenas_apiv4_host} || croak("Host is required"),
        username => $scfg->{truenas_user},
        password => $scfg->{truenas_password},
        secure   => $scfg->{truenas_use_ssl} || 0,
        apikey   => $scfg->{truenas_apikey},
        iqn      => $scfg->{target},
        target   => undef,
        targets  => {},

        # Client
        auth        => 0,
        client      => undef,
        conn        => undef,
        connected   => 0,
        frame       => Protocol::WebSocket::Frame->new(),
        max_retries => 3,
        protocol    => 'jsonrpc',
        sock        => undef,
        timeout     => 10,
        lastcall    => undef,

        # Message Handling
        msg_id => 0,
        rpc    => JSON::RPC::Common::Marshal::Text->new,

        result => undef,
        error  => undef,
    };

    # Validation
    unless ( $self->{apikey} || ( $self->{username} && $self->{password} ) ) {
        croak("Either apikey or username/password must be provided");
    }

    # Set the target if provided
    set_target( $self, $self->{iqn} );

    # Build URLs for both endpoints
    my $scheme = $self->{secure} ? "wss://" : "ws://";
    $self->{endpoints} = [
        {
            url      => $scheme . $self->{host} . "/api/current",
            protocol => 'jsonrpc'
        },
        { url => $scheme . $self->{host} . "/websocket", protocol => 'ddp' }
    ];

    # Extract target

    bless $self, $class;
    return $self;
}

sub request {
    my ( $self, $method, @params ) = @_;

    _log($method, 'debug');

    unless ( $self->_is_connected() && $self->{auth} ) {
        $self->_connect();
        $self->_authenticate();
    }

    my ( $result, $error );

    # Construct message
    my $message = _message_gen( $self, $method, @params );
    _log( $message, 'debug' );

    $result = _call( $self, $message );
    return $result;

}

sub _authenticate {
    my ($self) = @_;
    my $message;
    my $result;

    if ( $self->{protocol} eq 'ddp' ) {

        # Send Connect
        $message = '{ "msg": "connect", "version": "1", "support": ["1"] }';
        $result  = $self->_call($message);
    }

    if ( $self->{apikey} ) {
        $message = $self->_message_gen( 'auth.login_with_api_key', $self->{apikey} );
        $result  = $self->_call($message);
    }
    else {
        $message = $self->_message_gen( 'auth.login', $self->{username}, $self->{password} );
        $result  = $self->_call($message);
    }

    if ($result) {
        $self->{auth} = 1;
        _log("Authenticated");
    }
    else {
        $self->{auth} = 0;
        _log( "Authentication failed", 'error' );
        croak "Authentication failed";
        return;
    }
}

# Reads WebSocket response with timeout and returns decoded result
sub _call {
    my $self    = shift;
    my $message = shift;
    my $timeout = shift // $self->{timeout};
    my $result;
    my $response;

    $self->_send($message);

    eval { $response = $self->_receive($timeout); };
    if ($@) {
        _log( "Receive failed: $@", 'error' );
        $self->_disconnect;
        return;
    }
    if ( !defined $response ) {
        _log( "No response received", 'error' );
        $self->_disconnect;
        return;
    }

    $result = $self->_handle_response($response);
    return $result;

}

sub _connect {
    my ($self) = @_;

    my $sock;
    my $last_error;

    for my $endpoint ( @{ $self->{endpoints} } ) {
        my $url = $endpoint->{url};
        $self->{protocol} = $endpoint->{protocol};

        eval {
            if ( $self->{secure} ) {
                $sock = IO::Socket::SSL->new(
                    PeerHost        => $self->{host},
                    PeerPort        => 443,
                    SSL_verify_mode => 0,
                ) or croak "SSL connect failed: $!";
            }
            else {
                $sock = IO::Socket::IP->new(
                    PeerAddr => $self->{host},
                    PeerPort => 80,
                    Proto    => 'tcp',
                ) or croak "TCP connect failed: $!";
            }
        };
        if ($@) {
            $last_error = $@;
            _log( "Socket connection failed for  $last_error", 'warn' );
            next;    # Try the next endpoint
        }

        # Handshake
        _log( $url, 'debug' );
        my $handshake;
        my $response = '';
        eval {
            $handshake = Protocol::WebSocket::Handshake::Client->new( url => $url );
            print $sock $handshake->to_string;

            while (<$sock>) {
                $response .= $_;
                last if $_ =~ /^\r?\n$/;
            }
            $handshake->parse($response);

        };
        if ( $@ || !$handshake->is_done ) {
            $last_error = $@ || $handshake->error;
            _log( "Handshake failed: $last_error", 'error' );
            close($sock) if $sock;
            $sock = undef;
            next;
        }

        $self->{connected} = 1;
        $self->{sock}      = $sock;
        _log("Connected");
        return;
    }
    croak "Failed to connect to any endpoint: $last_error";

}

# Gracefully close the WebSocket connection
sub _disconnect {
    my ($self) = @_;
    return unless $self->{sock};

    # eval {
    #     my $frame = Protocol::WebSocket::Frame->new(
    #         type   => 'close',
    #         buffer => '',
    #     );
    #     syswrite( $self->{sock}, $frame->to_bytes );
    # };

    close( $self->{sock} );
    $self->{sock}      = undef;
    $self->{connected} = 0;
    $self->{auth}      = 0;

    _log("Disconnected");

    return;
}

# Handle incoming JSON-RPC responses
sub _handle_response {
    my ( $self, $data ) = @_;

    _log( $data, 'debug' );

    my ( $failed, $result, $error ) = _message_parse( $self, $data );
    if ($failed) {
        on_error( $self, "Message Parse Failed" );
        return;
    }
    elsif ($error) {
        on_error( $self, $error );
        return;
    }
    $self->{result} = $result;
    _log( "Result: " . Dumper($result), 'debug' );
    return $result;
}

# Check if the socket is connected
sub _is_connected {
    my ($self) = @_;

    return 0 unless $self->{sock} && $self->{connected};

    if ( time - $self->{lastcall} >= 60 ) {
        _log("Connection timed out");
        $self->_disconnect;
        return 0;
    }

    if ( time - $self->{lastcall} >= 30 ) {
        _log("Ping");
        my $message = $self->_message_gen('core.ping');
        $self->_send($message);
        my $response = $self->_receive(2);    # Wait for pong response
        if ( !defined $response ) {
            _log( "Ping failed", 'error' );
            $self->_disconnect;
            return 0;
        }
        my $result = $self->_handle_response($response);
        if ( $result ne 'pong' ) {
            _log( "Ping failed", 'error' );
            $self->_disconnect;
            return 0;
        }
        _log("Pong");
    }

    return 1;
}

# Send data over the WebSocket
sub _send {
    my ( $self, $message ) = @_;
    my $frame  = Protocol::WebSocket::Frame->new($message);
    my $result = syswrite( $self->{sock}, $frame->to_bytes );
    croak "Write failed: $!" unless defined $result;
}

# Recieve data from the WebSocket with timeout
sub _receive {
    my $self    = shift;
    my $timeout = shift;
    my $start   = time;
    my $buffer;

    while ( ( time - $start ) < $timeout ) {
        my $read;
        my $buffer;

        do {
            $read = sysread( $self->{sock}, $buffer, 65536 );
            if ( !defined($read) ) {
                next if $! == EINTR;
                croak "Read failed: $!";
            }
            elsif ( $read == 0 ) {
                _log( "Connection closed", 'warn' );
                $self->_disconnect;
                return;
            }
        } while ( !defined($read) );

        $self->{frame}->append($buffer);
        while ( my $response = $self->{frame}->next ) {
            $self->{lastcall} = time;
            return $response;
        }

        select( undef, undef, undef, 0.01 );    # avoid tight loop
    }

    croak "Timeout waiting for response after ${timeout}s";
}

# Destructor: ensure the socket is closed on object destruction
sub DESTROY {
    my ($self) = @_;
    $self->_disconnect;
}

# HELPERS

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

sub _message_gen {
    my $self   = shift;
    my $method = shift;
    my @params = @_;

    my $message;
    my $id = $self->{msg_id}++;

    @params = _message_sanatize(@params);

    if ( $self->{protocol} eq 'jsonrpc' ) {
        my $rpc = $self->{rpc};

        my $call = JSON::RPC::Common::Procedure::Call->inflate(
            jsonrpc => '2.0',
            id      => $id,
            method  => $method,
            params  => \@params,
        );
        $message = $rpc->call_to_json($call);
    }
    elsif ( $self->{protocol} eq 'ddp' ) {

        $message = {
            msg     => 'method',
            method  => $method,
            params  => \@params,
            id      => $id,
            version => '1',
        };
        $message = encode_json($message);

    }

    return $message;
}

sub _message_parse {
    my ( $self, $data ) = @_;

    my $failed = 0;
    my $result = undef;
    my $error  = undef;

    if ( $self->{protocol} eq 'jsonrpc' ) {
        my $rpc = $self->{rpc};
        my $message;
        $message = $rpc->json_to_return($data);
        if ( defined $message->{error} ) {
            $error = $message->{error};
            return ( undef, undef, $error );
        }
        elsif ( defined $message->{result} ) {
            $result = $message->{result};
            return ( undef, $result, undef );
        }
        else {
            $failed = 1;
            return ( $failed, undef, undef );
        }

    }
    elsif ( $self->{protocol} eq 'ddp' ) {
        my $message;
        eval { $message = decode_json($data) };
        if ($@) {
            $failed = 1;
            return ( $failed, undef, undef );
        }
        if ( $message->{msg} eq 'connected' ) {
            return ( undef, 1, undef );
        }
        if ( $message->{msg} eq 'result' ) {
            if ( defined $message->{error} ) {
                return ( undef, undef, $message->{error} );
            }
            else {
                return ( undef, $message->{result}, undef );
            }
        }

    }
}

# Sanitize numbers as strings
sub _message_sanatize {
    my @params = @_;

    for my $item (@params) {
        if ( ref($item) eq 'HASH' ) {

            # Recursively process hash values
            for my $key ( keys %$item ) {
                $item->{$key} = ( _message_sanatize( $item->{$key} ) )[0];
            }
        }
        elsif ( ref($item) eq 'ARRAY' ) {

            # Recursively process array elements
            @$item = _message_sanatize(@$item);
        }
        elsif ( !ref($item) && defined($item) && $item =~ /^-?\d*\.?\d+$/ ) {

            # Convert string that looks like a number to a number
            $item = $item + 0;
        }
    }

    return @params;
}

# EVENTS

sub on_error {
    my $self  = shift;
    my $error = shift;
    my $message;

    if ( $self->{protocol} eq 'jsonrpc' ) {
        $message = $error->{data}{reason};
    }
    elsif ( $self->{protocol} eq 'ddp' ) {
        $message = $error->{type} . " : " . $error->{reason};
    }
    $self->{error} = $message;
    _log( $message, 'error' );
    _log( $error, 'debug' );

}

# PROPERTIES

sub response {
    my ($self) = @_;
    return $self->{result};
}

sub set_target {
    my ( $self, $iqn ) = @_;

    if ( $iqn =~ /^(iqn\.\d{4}-\d{2}\.[^:]+):(.+)$/ ) {
        my $prefix = $1;
        my $target = $2;
        $self->{target} = $target;
    }
    else {
        croak("Invalid IQN format, expected 'iqn:target'");
    }
    _log( "Target set to: " . $self->{target}, 'debug' );
}

sub has_error {
    my ($self) = @_;
    return defined( $self->{error} );
}

## ISCSI METHODS

sub iscsi_global_config {
    my ($self) = @_;
    my $result = $self->request('iscsi.global.config');
    if ( $self->has_error ) {
        return;
    }
    return $result;
}

sub iscsi_target_query {
    my $self   = shift;
    my @params = @_;

    my $result = $self->request( 'iscsi.target.query', @params );
    if ( $self->has_error ) {
        return;
    }
    return $result;
}

sub iscsi_target_getid {
    my $self        = shift;
    my $target_name = shift;

    # Check target cache first
    if ( defined $self->{targets}{$target_name} ) {
        return $self->{targets}{$target_name};
    }

    # If not cached, query the target
    my $query  = _build_query( { name => $target_name } );
    my $result = $self->request( 'iscsi.target.query', $query, {} );
    if ( $self->{error} ) {
        _log( "Failed to get target ID: " . $self->{error}, 'error' );
        return;
    }
    if ($result) {
        $result = $result->[0];
        $self->{targets}{$target_name} = $result->{id};
        _log( "Target ID for $target_name: " . $result->{id}, 'debug' );
        return $result->{id};
    }
    else {
        return undef;
    }

}

sub iscsi_targetextent_query {
    my $self   = shift;
    my $params = shift;

    my $query  = _build_query($params);
    my $result = $self->request( 'iscsi.targetextent.query', $query, {} );
    if ( $self->{error} ) {
        _log( "Failed to get target extent: " . $self->{error}, 'error' );
        return;
    }
    return $result;
}

sub iscsi_lun_get {

    my $self        = shift;
    my $path        = shift;
    my $target_name = shift || $self->{target};
    my $query;

    my $target_id = $self->iscsi_target_getid($target_name);

    $query = _build_query( { path => $path } );
    my $extent = $self->request( 'iscsi.extent.query', $query, {} );
    if (@$extent) {
        $extent = $extent->[0];
    }
    else {
        return undef;
    }

    $query = _build_query( { target => $target_id, extent => $extent->{id} } );
    my $targetextent = $self->request( 'iscsi.targetextent.query', $query, {} );
    if (@$targetextent) {
        $targetextent = $targetextent->[0];
    }
    else {
        return undef;
    }

    $extent->{lunid}  = $targetextent->{lunid};
    $extent->{target} = $target_id;

    return $extent;

}

sub iscsi_lun_create {
    my $self     = shift;
    my $path     = shift;
    my $MAX_LUNS = shift || 255;

    # Get the next id
    my $lun_id    = $self->iscsi_lun_nextid();
    my $target_id = $self->iscsi_target_getid( $self->{target} );

    if ( $lun_id >= $MAX_LUNS ) {
        _log( "LUN ID exceeds maximum: $MAX_LUNS", 'error' );
        return;
    }

    ( my $disk = $path ) =~ s{^/dev/}{};
    ( my $name = $disk ) =~ s{^zvol/}{};

    # Create extent
    my $params = { name => $name, type => 'DISK', disk => $disk, };
    my $extent = $self->request( 'iscsi.extent.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create LUN: " . $self->{error}, 'error' );
        return;
    }

    # Create targetextent
    $params = { target => $target_id, extent => $extent->{id}, lunid => $lun_id };
    my $targetextent = $self->request( 'iscsi.targetextent.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create target extent: " . $self->{error}, 'error' );
        return;
    }

    if ( defined $targetextent ) {
        _log( "$path : T" . $target_id . ":E" . $extent->{'id'} . ":L" . $lun_id );
    }
    else {
        _log( "Failed to create target extent: " . $self->{error}, 'error' );
        return;
    }

    return 1;

}

sub iscsi_lun_delete {
    my ( $self, $path ) = @_;

    my $lun = $self->iscsi_lun_get( $path, $self->{target} );
    if ( !$lun ) {
        _log( "LUN not found: $path", 'error' );
        return;
    }
    my $result = $self->request( 'iscsi.extent.delete', $lun->{id}, \0, \1 );    # Force delete
    if ($result) {
        _log("LUN deleted: $path");
        return 1;
    }
    else {
        _log( "Failed to delete LUN: $path", 'error' );
    }

}

sub iscsi_lun_nextid {
    my $self = shift;

    my $target_id     = $self->iscsi_target_getid( $self->{target} );
    my $targetextents = $self->iscsi_targetextent_query( { target => $target_id } );

    my @luns = ();
    foreach my $item (@$targetextents) {
        push( @luns, $item->{lunid} );
    }

    my @sorted_luns = sort { $a <=> $b } @luns;
    my $lun_id      = 0;

    # find the first hole, if not, give the +1 of the last lun
    foreach my $lun (@sorted_luns) {
        last if $lun != $lun_id;
        $lun_id++;
    }

    _log($lun_id);

    return $lun_id;
}

sub iscsi_lun_recreate {
    my $self = shift;
    my $path = shift;

    ( my $lun_path = $path ) =~ s{/dev/zvol/}{};

    $self->iscsi_lun_delete($lun_path);
    $self->iscsi_lun_create($path);
}

sub zfs_snapshot_create {
    my $self   = shift;
    my @params = shift;

    my $object = $params[0];
    my ( $dataset, $name ) = split( '@', $object );

    my $params = { dataset => $dataset, name => $name, };
    my $result = $self->request( 'pool.snapshot.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create snapshot: " . $self->{error}, 'error' );
        return;
    }
    return $result;
}

sub zfs_snapshot_list {
    my $self   = shift;
    my @params = shift;

    my $object = $params[0];

    my $query = [ [ 'dataset', '=', $object ] ];

    my $options = { select => [ 'name', 'dataset', 'snapshot_name', 'properties', 'createtxg' ], order_by => ['createtxg'] };

    # my $options = {};

    my $result = $self->request( 'pool.snapshot.query', $query, $options );
    if ( $self->has_error ) {
        _log( "Failed to list snapshots: " . $self->{error}, 'error' );
        return;
    }
    return $result;
}

sub zfs_snapshot_delete {
    my $self   = shift;
    my @params = shift;

    my $object = $params[0];

    my $result = $self->request( 'pool.snapshot.delete', $object );
    return $result;
}

sub zfs_snapshot_rollback {
    my $self   = shift;
    my @params = shift;

    my $object = $params[0];

    my $result = $self->request( 'pool.snapshot.rollback', $object );
    if ( $self->has_error ) {
        _log( "Failed to rollback snapshot: " . $self->{error}, 'error' );
        return;
    }
    return $result;
}

sub zfs_zvol_list {
    my $self   = shift;
    my @params = shift;

    _log("Listing zvols");

    my $query   = [ [ 'name', '^', 'tank/proxmox' ], [ 'type', '=', 'VOLUME' ] ];
    my $options = {
        extra  => { retrieve_children => \0 },
        select => [ 'name', 'volsize', 'origin', 'type', 'refquota' ]

    };
    my $result = $self->request( 'pool.dataset.query', $query, $options );
    if ( $self->has_error ) {
        _log( "Failed to get zvol list: " . $self->{error}, 'error' );
        return;
    }
    my $text = "";
    for my $zvol (@$result) {
        $text .= $zvol->{name} . " " . ( $zvol->{volsize}{rawvalue} || '-' ) . " " . ( $zvol->{origin}{rawvalue} || '-' ) . " " . ( lc( $zvol->{type} ) ) . " " . ( $zvol->{refquota}{rawvalue} // '-' ) . "\n";
    }

    return $text;
}

sub zfs_zvol_create {
    my ( $self, $zvol, $size, $blocksize, $sparce ) = @_;

    _log("Creating zvol: $zvol with size: $size");

    my $params = {
        name         => $zvol,
        volsize      => $size,
        volblocksize => uc $blocksize,
        sparse       => $sparce ? \1 : \0,    # JSON boolean
        type         => 'VOLUME'
    };
    my $result = $self->request( 'pool.dataset.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create zvol: " . $self->{error}, 'error' );
        return;
    }
    return 1;
}

sub zfs_zvol_delete {
    my ( $self, $zvol ) = @_;

    _log("Destroying zvol: $zvol");

    my $options = {
        force     => \1,    # Force delete
        recursive => \0,    # Do not delete children datasets
    };

    my $result = $self->request( 'pool.dataset.delete', $zvol, $options );
    if ( $self->has_error ) {
        _log( "Failed to destroy zvol: " . $self->{error}, 'error' );
        return;
    }
    return 1;
}

sub zfs_zvol_resize {
    my ( $self, $zvol, $size, $attr ) = @_;

    _log("Resizing zvol: $zvol to size: $size");

    my $options = { $attr => $size, };

    my $result = $self->request( 'pool.dataset.update', $zvol, $options );
    if ( $self->has_error ) {
        _log( "Failed to update zvol: " . $self->{error}, 'error' );
        return;
    }
    return 1;

}

sub zfs_zpool_get {
    my ( $self, $pool ) = @_;

    _log("Query zpool: $pool");

    my $query   = [ [ 'name', '=', $pool ] ];
    my $options = { get => \1 };

    my $result = $self->request( 'pool.query', $query, $options );
    if ( $self->has_error ) {
        _log( "Failed to get zpool: " . $self->{error}, 'error' );
        return;
    }
    return $result;

}

1;
