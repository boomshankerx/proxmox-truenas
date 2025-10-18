package TrueNAS::Helpers;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(_log _debug justify bytes2gb);

use Data::Dumper;
use JSON;
use Log::Any qw($log);
use Log::Any::Adapter;
use PVE::SafeSyslog;
use Scalar::Util qw(reftype);

# Logging
our $ADAPTER = Log::Any::Adapter->set( 'Stdout', log_level => 'info' );
my %LOG_LEVEL    = ( debug => 1,       info => 2,      notice => 3,        warning => 4,         error => 5 );
my %SYSLOG_LEVEL = ( debug => 'debug', info => 'info', notice => 'notice', warn    => 'warning', error => 'err' );

# Logging Helper
sub _log {
    my $message = shift;
    my $level   = shift || 'info';

    my $min = eval { $ADAPTER->{adapter_params}[1] };
    if ($min) {
        return if ( $LOG_LEVEL{$level} // 99 ) < ( $LOG_LEVEL{$min} // 1 );
    }

    # If debugging add calling context
    if ( $LOG_LEVEL{$min} == 1 ) {
        if ( defined reftype($message) ) {
            $message = Dumper($message);
        }
        my $src = ( caller(1) )[3] || ( caller(0) )[3] || 'main';
        $src     = ( split( /::/, $src ) )[-1];
        $message = "TrueNAS [" . uc($level) . "] $src : $message";
    }
    else {
        $message = "TrueNAS [" . uc($level) . "] : $message";
    }

    $log->$level($message);
    syslog( "$SYSLOG_LEVEL{$level}", $message );
}

sub _debug {
    my @args = @_;

    # Convert args to strings like _log does
    my @out = map {
        if ( defined reftype($_) ) {
            chomp( my $dump = Dumper($_) );
            $dump;
        }
        else {
            defined $_ ? $_ : 'undef';
        }
    } @args;

    my $src = ( caller(1) )[3] || ( caller(0) )[3] || 'main';
    $src = ( split /::/, $src )[-1];

    my $message = "########################\n";
    $message .= "[DEBUG]: TrueNAS: $src : " . join( ", ", @out );
    $message .= "\n########################\n";

    $log->debug($message);
    syslog( $SYSLOG_LEVEL{'debug'} // 'debug', $message );
}

sub justify {
    my $text      = shift;
    my $width     = shift || 10;
    my $justified = sprintf( "%${width}s", $text );
    return $justified;
}

sub bytes2gb {
    my $bytes = shift || 0;
    return sprintf( "%.2f", $bytes / ( 1024 * 1024 * 1024 ) );
}

1;
