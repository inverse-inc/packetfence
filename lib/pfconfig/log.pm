package pfconfig::log;

use strict;
use warnings;

use Log::Fast;
use Sys::Syslog qw( LOG_DAEMON );
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_logger);

my $logger = pfconfig::log->new;

sub get_logger {
    return $logger;
}

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

sub fatal {
  my ($self, $message) = @_;
  $message .= " (".whowasi().")";
  $self->{logger}->ERR($message);
}

sub error {
  my ($self, $message) = @_;
  $message .= " (".whowasi().")";
  $self->{logger}->ERR($message);
}

sub warn {
  my ($self, $message) = @_;
  $message .= " (".whowasi().")";
  $self->{logger}->WARN($message);
}

sub info {
  my ($self, $message) = @_;
  $message = "$message (".whowasi().")";
  $self->{logger}->INFO($message);
}

sub debug {
  my ($self, $message) = @_;
  $message .= " (".whowasi().")";
  $self->{logger}->DEBUG($message);
}

sub trace {
  my ($self, $message) = @_;
  $message .= " (".whowasi().")";
  $self->{logger}->DEBUG($message);
}

sub whowasi { ( caller(2) )[3] }

1;
