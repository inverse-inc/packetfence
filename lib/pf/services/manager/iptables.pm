package pf::services::manager::iptables;

=head1 NAME

pf::services::manager::iptables

=cut

=head1 DESCRIPTION

Service manager for iptables

=cut

use Moo;

extends 'pf::services::manager';

has '+name' => ( default => sub { 'iptables' } );

has '+shouldCheckup' => ( default => sub { 1 } );

has '+launcher' => ( default => sub { "iptables" } );

has '+startDependsOnServices' => ( is => 'ro', default => sub { ["ipset"] } );

has 'runningServices' => ( is => 'rw', default => sub { 0 } );


=head2 startService

"Start" iptables by generating rules

=cut

sub startService {
    my ( $self ) = @_;

    # Saving existing system rules
    pf::iptables::save() unless ($self->runningServices);

    # Flushing currently configured rules
    pf::iptables::flush();

    # Generating and applying PacketFence rules
    pf::iptables::restore(pf::iptables::generate());

    # Since iptables is not a running service, it doesn't have a PID associated to it.
    # We use -1 as a PID for theses kind of "services"
    open (my $fh, '>>' . $self->pidFile);
    print $fh "-1";
    close ($fh);

    return 1;
}

=head2 start

Wrapper around systemctl. systemctl should in turn call the actuall _start.

=cut

sub start {
    my ($self,$quick) = @_;
    system('sudo systemctl start packetfence-iptables');
    return $? == 0;
}

=head2 _start

start the service (called from systemd)

=cut

sub _start {
    my ($self) = @_;
    my $result = 0;
    unless ( $self->isAlive() ) {
        $result = $self->startService();
    }
    return $result;
}

sub startAndCheck {
    my ($self) = @_;

    while(1) {
        $self->_start() unless($self->isAlive());
        sleep 60;
    }
}

=head2 stop

Wrapper around systemctl. systemctl should in turn call the actual _stop.
=head2 stop

"Stop" iptables by flushing rules

=cut

sub stop {
    my ($self) = @_;
    system('sudo systemctl stop packetfence-iptables');
    return 1;
}

=head2 _stop

stop iptables (called from systemd)

=cut

sub _stop {
    my ( $self ) = @_;

    # Flushing PacketFence rules
    pf::iptables::flush();

    # Restoring previously configured (system?) rules
    pf::iptables::restore();

    unlink $self->pidFile;

    return 1;
}

=head2 isAlive

Check if iptables is alive.
Since it is never really stopped then we check if rules are defined and if the fake PID exists

=cut

sub isAlive {
    my ( $self, $pid ) = @_;

    $pid = $self->pid;
    my $running = pf::iptables::check();

    return ( defined($pid) && $running );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
