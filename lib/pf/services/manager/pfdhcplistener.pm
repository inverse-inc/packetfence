package pf::services::manager::pfdhcplistener;
=head1 NAME

pf::services::manager::pfdhcplistener add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::pfdhcplistener

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(
    %Config
    @listen_ints
    @dhcplistener_ints
);
use pf::file_paths qw(
    $var_dir
    $install_dir
    $systemd_unit_dir
);
use pf::util;
use List::MoreUtils qw(any all uniq);
use pf::log;

extends 'pf::services::manager::submanager';

has pfdhcplistenerManagers => ( is => 'rw', builder => 1, lazy => 1);

has '+name' => (default => sub { 'pfdhcplistener'} );

has 'int' => (is => 'ro');

sub _cmdLine {
    my $self = shift;
    "$install_dir/sbin/pfdhcplistener -i " . $self->int;
}

sub _build_pfdhcplistenerManagers {
    my ($self) = @_;
    my @managers = map {
        pf::services::manager::pfdhcplistener->new(
            {   name                    => "pfdhcplistener_$_",
                forceManaged            => $self->isManaged,
                orderIndex              => $self->orderIndex,
                systemdTemplateFilePath => $self->systemdTemplateFilePath,
                unitFilePath            => $systemd_unit_dir . "/packetfence-" . "pfdhcplistener_$_" . ".service",
                int                     => $_,
            }
            )
    } uniq @listen_ints, @dhcplistener_ints;
    return \@managers;
}

sub managers {
    my ($self) = @_;
    return @{$self->pfdhcplistenerManagers};
}

sub isManaged {
    my ($self) = @_;
    return (isenabled($Config{'network'}{'dhcpdetector'}) && isenabled($Config{'services'}{$self->name}));
}

=head2 start, stop, status

We alias these methods to the ones in the services::manager class.
This avoids infinite recursion when calling status since pf::services::manager::submanager::status calls managers().

=cut

*status = \&pf::services::manager::status;
*stop   = \&pf::services::manager::stop;
*start  = \&pf::services::manager::start;
*startService  = \&pf::services::manager::startService;
*postStartCleanup  = \&pf::services::manager::postStartCleanup;
*postStopCleanup  = \&pf::services::manager::postStopCleanup;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

