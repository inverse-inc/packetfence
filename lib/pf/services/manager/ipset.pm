package pf::services::manager::ipset;

=head1 NAME

pf::services::manager::ipset

=cut

=head1 DESCRIPTION

Service manager for ipset

=cut

use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub { 'ipset' } );

has '+shouldCheckup' => ( default => sub { 1 } );

has '+launcher' => ( default => sub { "ipset" } );

has '+stopDependsOnServices' => ( is => 'ro', default => sub { ["iptables"] } );

has 'runningServices' => ( is => 'rw', default => sub { 0 } );


=head2 startService

"Start" ipset by generating sets

=cut

sub startService {
    my ( $self ) = @_;

    # Saving existing system sets
    pf::ipset::save() unless ($self->runningServices);

    # Flushing currently configured sets
    pf::ipset::flush();

    # Generating and applying PacketFence sets
    pf::ipset::restore(pf::ipset::generate());

    # Since ipset is not a running service, it doesn't have a PID associated to it.
    # We use -1 as a PID for theses kind of "services"
    open (my $fh, '>>' . $self->pidFile);
    print $fh "-1";
    close ($fh);

    return 1;
}

=head2 stop

"Stop" ipset by flushing sets

=cut

sub stop {
    my ( $self ) = @_;

    # Flushing PacketFence sets
    pf::ipset::flush();

    # Restoring previously configured (system?) sets
    pf::ipset::restore();

    unlink $self->pidFile;

    return 1;
}

=head2 isAlive

Check if ipset is "alive"
Since it is never really stopped then we check if sets are defined and if the fake PID exists

=cut

sub isAlive {
    my ( $self, $pid ) = @_;

    $pid = $self->pid;
    my $running = pf::ipset::check();

    return ( defined($pid) && $running );
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
