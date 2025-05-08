package TrueNAS::Client;
use strict;
use warnings;
use Errno qw(EINTR);

use IO::Socket::INET;
use IO::Socket::SSL;
use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Frame;
use JSON::RPC::Common::Procedure::Call;
use JSON::RPC::Common::Procedure::Return;
use JSON::RPC::Common::Procedure::Return::Error;
use JSON::RPC::Common::Marshal::Text;

use Carp;
use Data::Dumper;
use JSON;
use Log::Any qw($log);
use Log::Any::Adapter;
use PVE::SafeSyslog;

sub new {
    my ( $class, $args ) = @_;

    my $self = {
        debug     => $args->{debug}              || 0,
        host      => $args->{freenas_apiv4_host} || croak("host is required"),
        username  => $args->{freenas_user},
        password  => $args->{freenas_password},
        secure    => $args->{freenas_use_ssl} || 0,
        token     => $args->{token},
        iqn       => $args->{target},
        target    => undef,
        target_id => undef,

        # Client
        client    => undef,
        conn      => undef,
        timeout   => 10,
        url       => undef,
        connected => 0,
        auth      => 0,
        sock      => undef,
        frame     => Protocol::WebSocket::Frame->new(),

        # Message Handling
        msg_id  => 0,
        pending => {},
        rpc     => JSON::RPC::Common::Marshal::Text->new,

        result => undef,
        error  => undef,
    };

    # Validation
    unless ( $self->{token} || ( $self->{username} && $self->{password} ) ) {
        croak("Either token or username/password must be provided");
    }

    # Build URL
    my $scheme = $self->{secure} ? "wss://" : "ws://";
    $self->{url} = $scheme . $self->{host} . "/api/current";
    _log( "URL: " . $self->{url}, 'debug' );

    # Extract target
    $self->{target} = ( split( /:/, $self->{iqn} ) )[-1];

    bless $self, $class;
    return $self;
}

sub connect {
    my ($self) = @_;

    my $sock;
    if ( $self->{secure} ) {
        $sock = IO::Socket::SSL->new(
            PeerHost        => $self->{host},
            PeerPort        => 443,
            SSL_verify_mode => 0,
        ) or die "SSL connect failed: $!";
    }
    else {
        $sock = IO::Socket::INET->new(
            PeerAddr => $self->{host},
            PeerPort => 80,
            Proto    => 'tcp',
        ) or die "TCP connect failed: $!";
    }

    my $handshake = Protocol::WebSocket::Handshake::Client->new( url => $self->{url} );
    print $sock $handshake->to_string;

    my $response = '';
    while (<$sock>) {
        $response .= $_;
        last if $_ =~ /^\r?\n$/;
    }
    die "Handshake failed" unless $response =~ m/101 Switching Protocols/;
    _log( $response, 'debug' );

    $self->{connected} = 1;
    $self->{sock}      = $sock;
    _log("Connected");

}

sub _authenticate {
    my ($self) = @_;

    _log( "Authenticating", 'debug' );

    my $message = $self->_rpc_gen( 'auth.login', $self->{username}, $self->{password} );
    my $result  = $self->_call($message);

    if ($result) {
        $self->{auth} = 1;
        _log("Authenticated");
    }
    else {
        $self->{auth} = 0;
        _log( "Authentication failed", 'error' );
        return;
    }
}

# Reads WebSocket response with timeout and returns decoded result
sub _call {
    my $self    = shift;
    my $message = shift;

    # Write message to socket
    my $frame = Protocol::WebSocket::Frame->new( buffer => $message );
    print { $self->{sock} } $frame->to_bytes;

    $self->_receive();

}

sub _receive {
    my $self    = shift;
    my $timeout = shift // $self->{timeout};    # seconds
    my $start   = time;

    my $read;
    my $chunk;

    # Read response from socket
    while ( ( time - $start ) < $timeout ) {
        do {
            $read = sysread( $self->{sock}, $chunk, 65536 );
        } while ( !defined($read) && $! == EINTR );
        die "Read failed: $!" unless defined $read && $read > 0;
        $self->{frame}->append($chunk);

        while ( my $response = $self->{frame}->next ) {
            if ( $self->{frame}->is_close ) {
                $self->disconnect;
            }
            return $self->_handle_response($response);
        }
        select( undef, undef, undef, 0.01 );    # short sleep to avoid tight loop
    }

    die "Timeout waiting for response";

}

sub request {
    my ( $self, $method, @params ) = @_;

    _log( $method, 'debug' );

    if ( !$self->{connected} || !$self->{auth} ) {
        $self->connect();
        $self->_authenticate();
    }

    my ( $result, $error );

    # Construct message
    my $message = _rpc_gen( $self, $method, @params );
    _log( $message, 'debug' );

    $result = _call( $self, $message );
    return $result;

}

# Handle incoming JSON-RPC responses
sub _handle_response {
    my ( $self, $data ) = @_;

    _log( $data, 'debug' );

    my $id = _get_id($data);

    my ( $failed, $result, $error ) = _rpc_parse( $self, $data );
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

# Gracefully close the WebSocket connection
sub disconnect {
    my ($self) = @_;
    return unless $self->{sock};

    _log("Disconnecting");

    eval {
        my $frame = Protocol::WebSocket::Frame->new(
            type   => 'close',
            buffer => '',
        );
        print { $self->{sock} } $frame->to_bytes;
    };

    close( $self->{sock} );
    $self->{sock} = undef;
    $self->{connected} = 0;
    $self->{auth}      = 0; 
}

# Destructor: ensure the socket is closed on object destruction
sub DESTROY {
    my ($self) = @_;
    $self->disconnect;
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

    if ( defined $self->{target_id} ) {
        return $self->{target_id};
    }

    else {

        my $query  = _build_query( { name => $target_name } );
        my $result = $self->request( 'iscsi.target.query', $query, {} );
        if ( $self->{error} ) {
            _log( "Failed to get target ID: " . $self->{error}, 'error' );
            return;
        }
        if ($result) {
            $result = $result->[0];
            $self->{target_id} = $result->{id};
            return $self->{target_id};
        }
        else {
            return undef;
        }

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

    $extent->{lunid}  = $targetextent->{id};
    $extent->{target} = $target_id;

    return $extent;

}

sub iscsi_lun_create {
    my $self     = shift;
    my $lun_path = shift;
    my $MAX_LUNS = shift || 255;

    # Get the next id
    my $lun_id    = $self->iscsi_lun_nextid();
    my $target_id = $self->iscsi_target_getid( $self->{target} );

    if ( $lun_id >= $MAX_LUNS ) {
        _log( "LUN ID exceeds maximum: $MAX_LUNS", 'error' );
        return;
    }

    ( my $disk = $lun_path ) =~ s{^/dev/}{};
    ( my $name = $disk )     =~ s{^zvol/}{};

    # Create extent
    my $params = { name => $name, type => 'DISK', disk => $disk, };
    my $extent = $self->request( 'iscsi.extent.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create LUN: " . $self->{error}, 'error' );
        return;
    }

    # Create targetextent
    $params = { target => $self->{target_id}, extent => $extent->{id}, lunid => $lun_id };
    my $targetextent = $self->request( 'iscsi.targetextent.create', $params );
    if ( $self->has_error ) {
        _log( "Failed to create target extent: " . $self->{error}, 'error' );
        return;
    }

    if ( defined $targetextent ) {
        _log( "$lun_path : T" . $target_id . ":E" . $extent->{'id'} . ":L" . $lun_id );
    }
    else {
        _log( "Failed to create target extent: " . $self->{error}, 'error' );
        return;
    }

    return 1;

}

sub iscsi_lun_delete {
    my ( $self, $path ) = @_;

    my $lun = iscsi_lun_get( $self, $path, $self->{target} );
    if ( !$lun ) {
        _log( "LUN not found: $path", 'error' );
        return;
    }
    my $result = $self->request( 'iscsi.extent.delete', $lun->{id} );
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

# PROPERTIES

sub response {
    my ($self) = @_;
    return $self->{result};
}

sub has_error {
    my ($self) = @_;
    return defined( $self->{error} );
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

sub _get_id {
    my $data = shift;
    my $id   = decode_json($data)->{id};
    return $id;
}

sub _rpc_gen {
    my $self   = shift;
    my $method = shift;
    my @params = @_;

    my $rpc = $self->{rpc};
    my $id  = $self->{msg_id}++;

    @params = _rpc_sanitize(@params);

    my $call = JSON::RPC::Common::Procedure::Call->inflate(
        jsonrpc => '2.0',
        id      => $id,
        method  => $method,
        params  => \@params,
    );
    my $result = $rpc->call_to_json($call);

    return $result;
}

sub _rpc_parse {
    my ( $self, $data ) = @_;
    my $rpc = $self->{rpc};

    my $failed = 0;
    my $result = undef;
    my $error  = undef;

    my $response = eval { $rpc->json_to_return($data) };
    if ($@) {
        $failed = 1;
    }
    elsif ( defined $response->{error} ) {
        $error = $response->{error};
    }
    else {
        $result = $response->{result};
    }
    return ( $failed, $result, $error );
}

# Sanitize numbers as strings
sub _rpc_sanitize {
    my @params = @_;

    for my $item (@params) {
        if ( ref($item) eq 'HASH' ) {

            # Recursively process hash values
            for my $key ( keys %$item ) {
                $item->{$key} = ( _rpc_sanitize( $item->{$key} ) )[0];
            }
        }
        elsif ( ref($item) eq 'ARRAY' ) {

            # Recursively process array elements
            @$item = _rpc_sanitize(@$item);
        }
        elsif ( !ref($item) && defined($item) && $item =~ /^-?\d*\.?\d+$/ ) {

            # Convert string that looks like a number to a number
            $item = $item + 0;
        }
    }

    return @params;
}

# Logging Helper
sub _log {
    my $message = shift;
    my $level   = shift || 'info';

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
    if ( $level ne 'debug' ) {
        syslog( "$syslog_map->{$level}", $message );
    }
}

1;
