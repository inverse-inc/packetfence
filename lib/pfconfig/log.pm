package pfconfig::log;

=head1 NAME

pfconfig::log

=cut

=head1 DESCRIPTION

Used to create a Log::Fast logger that is faster than Log4perl

=cut

use strict;
use warnings;

use Log::Fast;
use Sys::Syslog qw( LOG_DAEMON );
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_logger);

=head2 logger

The logger object

=cut

my $logger = pfconfig::log->new;

=head2 get_logger

Used to get an instance of the module's logger

=cut

sub get_logger {
    return $logger;
}

=head2 new

Constructor for the logger

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;

    $self->{logger} = Log::Fast->global();

    open(my $fh, ">>", "/usr/local/pf/logs/pfconfig.log");

    $self->{logger}->config({
        level           => 'ERR',
        prefix          => '%D %T [%L] : ',
        type            => 'fh',
        fh              => $fh,
    });

    return $self;
}

=head2 fatal

Used for $logger->fatal($msg)
Logs to error since Log::Fast doesn't have fatal

=cut

sub fatal {
    my ($self, $message) = @_;
    $message .= " (".whowasi().")";
    $self->{logger}->ERR($message);
}

=head2 error

Used for $logger->error($msg)

=cut

sub error {
    my ($self, $message) = @_;
    $message .= " (".whowasi().")";
    $self->{logger}->ERR($message);
}

=head2 warn

Used for $logger->warn($msg)

=cut

sub warn {
    my ($self, $message) = @_;
    $message .= " (".whowasi().")";
    $self->{logger}->WARN($message);
}

=head2 info

Used for $logger->info($msg)

=cut

sub info {
    my ($self, $message) = @_;
    $message = "$message (".whowasi().")";
    $self->{logger}->INFO($message);
}

=head2 debug

Used for $logger->debug($msg)

=cut

sub debug {
    my ($self, $message) = @_;
    $message .= " (".whowasi().")";
    $self->{logger}->DEBUG($message);
}

=head2 trace

Used for $logger->trace($msg)
Logs to debug since Log::Fast doesn't have trace

=cut

sub trace {
    my ($self, $message) = @_;
    $message .= " (".whowasi().")";
    $self->{logger}->DEBUG($message);
}

sub whowasi { ( caller(2) )[3] }

1;
