package pf::eventlogger::syslog;

=head1 NAME

pf::eventlogger::syslog -

=head1 DESCRIPTION

pf::eventlogger::syslog

=cut

use strict;
use warnings;
use Moo;
use pf::Syslog;
extends 'pf::eventlogger';
use pf::cef;

has syslog_key => ( is => 'ro', builder => 1, lazy => 1);
has syslog_args => ( is => 'ro', builder => 1, lazy => 1);
has cef => ( is => 'ro', builder => 1, lazy => 1);
has facility => ( is => 'ro');
has priority => ( is => 'ro');
has port => ( is => 'ro');
has host => ( is => 'ro');

sub log_event {
    my ($self, $namespace, $event) = @_;
    my $cef = $self->cef;
    my $syslog = $self->syslog;
    my $msg = $cef->message($namespace, $event);
    $syslog->send($msg);
    return;
}

sub syslog {
    my ($self) = @_;
    return pf::Syslog->new($self->syslog_key, $self->syslog_args);
}

sub _build_cef {
    my ($self) = @_;
    return pf::cef->new(
        $self->cef_args()
    );
}

sub _build_syslog_key {
    my ($self) = @_;
    return join(
        ":",
        $self->facility,
        $self->priority,
        $self->port,
        $self->host,
    );
}

sub cef_args {
    my ($self) = @_;
    return {
        deviceEventClassId => '',
        name => '',
        severity => 0,
    };
}

sub _build_syslog_args {
    my ($self) = @_;
    return {
        Facility   => $self->facility,
        Priority   => $self->priority,
        SyslogPort => $self->port,
        SyslogHost => $self->host,
    };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
