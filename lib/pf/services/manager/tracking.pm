package pf::services::manager::tracking;

=head1 NAME

pf::services::manager::tracking add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::tracking

=cut

use strict;
use warnings;
use Moo;
use pf::log;
use pf::constants qw($TRUE $FALSE);

extends 'pf::services::manager';

has '+name' => (default => sub { 'tracking-config' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

has 'runningServices' => (is => 'rw', default => sub { 0 } );

has 'optional' => ( is => 'rw', default => sub { 1 } );

=head2 systemdTarget

systemdTarget

=cut

sub systemdTarget {
    my ($self) = @_;
    return "packetfence-" . $self->name . ".path";
}


=head2 start

Wrapper around systemctl. systemctl should in turn call the actuall _start.

=cut

sub start {
    my ($self,$quick) = @_;
    system('sudo systemctl start packetfence-tracking-config.path');
    return $? == $FALSE;
}

=head2 stop

Wrapper around systemctl. systemctl should in turn call the actual _stop.

=cut

sub stop {
    my ($self) = @_;
    system('sudo systemctl stop packetfence-tracking-config.path');
    return $TRUE;
}

=head2 pid

Returns the pid of the service

=cut

sub pid {
    my ($self) = @_;
    my $logger = get_logger();
    my $name = $self->{name};
    my $state = `sudo systemctl show -p ActiveState packetfence-$name.path`;
    chomp $state;
    $state = (split(/=/, $state))[1];
    if ($state ne "inactive") {
        $logger->debug("sudo systemctl packetfence-$name returned $state");
        return $TRUE;
    }
    return $FALSE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

