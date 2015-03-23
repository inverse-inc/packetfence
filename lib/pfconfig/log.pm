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

our @ISA    = qw(Exporter);
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

    open( my $fh, ">>", "/usr/local/pf/logs/pfconfig.log" );

    $self->{logger}->config(
        {   level  => 'ERR',
            prefix => '%D %T [%L] : ',
            type   => 'fh',
            fh     => $fh,
        }
    );

    return $self;
}

=head2 fatal

Used for $logger->fatal($msg)
Logs to error since Log::Fast doesn't have fatal

=cut

sub fatal {
    my ( $self, $message ) = @_;
    $message .= " (" . whowasi() . ")";
    $self->{logger}->ERR($message);
}

=head2 error

Used for $logger->error($msg)

=cut

sub error {
    my ( $self, $message ) = @_;
    $message .= " (" . whowasi() . ")";
    $self->{logger}->ERR($message);
}

=head2 warn

Used for $logger->warn($msg)

=cut

sub warn {
    my ( $self, $message ) = @_;
    $message .= " (" . whowasi() . ")";
    $self->{logger}->WARN($message);
}

=head2 info

Used for $logger->info($msg)

=cut

sub info {
    my ( $self, $message ) = @_;
    $message = "$message (" . whowasi() . ")";
    $self->{logger}->INFO($message);
}

=head2 debug

Used for $logger->debug($msg)

=cut

sub debug {
    my ( $self, $message ) = @_;
    $message .= " (" . whowasi() . ")";
    $self->{logger}->DEBUG($message);
}

=head2 trace

Used for $logger->trace($msg)
Logs to debug since Log::Fast doesn't have trace

=cut

sub trace {
    my ( $self, $message ) = @_;
    $message .= " (" . whowasi() . ")";
    $self->{logger}->DEBUG($message);
}

sub whowasi { ( caller(2) )[3] }

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

