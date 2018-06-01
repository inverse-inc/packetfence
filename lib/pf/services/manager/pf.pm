package pf::services::manager::pf;

=head1 NAME

pf::services::manager::pf
Service manager for the virtual service "pf".
This manager allows using pfcmd to manage the packetfence.target as a service.

=cut

=head1 DESCRIPTION

pf::services::manager::pf

=cut

use strict;
use warnings;
use Moo;
use pf::constants qw($TRUE);
use pf::log;
use pf::cluster;
extends 'pf::services::manager';

has '+name' => ( default => sub {'pf'} );

has isvirtual    => ( is => 'rw', default => sub {1} );
has forceManaged => ( is => 'rw', default => sub {1} );

sub _buildpidFile { 0; }

sub isManaged {
    my ($self) = @_;
    return 1;
}

sub start {
    my ( $self, $quick ) = @_;
    my $result = 0;
    if ( $self->startService($quick) ) {
        $result = $self->postStartCleanup($quick);
    }
    return $result;
}

sub postStartCleanup {
    my ( $self, $quick ) = @_;
    return $TRUE;
}

=head2 _build_launcher

Build the command to lauch the service.

=cut 

sub _build_launcher {
    my ($self) = @_;
    if($cluster_enabled) {
        return "sudo systemctl isolate packetfence-cluster.target";
    } else {
        return "sudo systemctl isolate packetfence.target";
    }
}

sub print_status {
    my ($self) = @_;
    my @output = `systemctl --all --no-pager`;
    my $header = shift @output;
    for (@output) {
        print if /packetfence.+\.service/;
    }
}


sub pid {
    my ($self) = @_;
    my @status;
    if($cluster_enabled) {
        @status = `sudo systemctl status packetfence-cluster.target`;
    } else {
        @status = `sudo systemctl status packetfence.target`;
    }
    my $pid = grep {/Active: active/} @status;
    return $pid;
}

=head2 stop

Stop the service waiting for it to shutdown

=cut

sub stop {
    my ( $self, $quick ) = @_;
    my $pid = $self->pid;
    if ($pid) {
        $self->stopService($quick);
        return 1;
    }
    return;
}

sub stopService {
    my ($self) = @_;
    my $logger = get_logger();
    $logger->info("Stopping packetfence.target");
    `sudo systemctl isolate packetfence-base.target`;
    if ( $? == -1 ) {
        $logger->error("failed to execute: $!\n");
    }
    else {
        $logger->info( "systemctl isolate packetfence-base  exited with value %d\n", $? >> 8 );
    }
}

=head2 systemdTarget

systemdTarget

=cut

sub systemdTarget {
    my ($self) = @_;
    return "packetfence.target";
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
