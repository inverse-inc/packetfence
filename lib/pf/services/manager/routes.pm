package pf::services::manager::routes;

=head1 NAME

pf::services::manager::routes add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::routes

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($install_dir);
use pf::log;
use pf::util;
use pf::config qw(
    %ConfigNetworks
);
use IPC::Cmd qw[can_run run];

extends 'pf::services::manager';

has '+name' => (default => sub { 'routes' } );

has '+shouldCheckup' => ( default => sub { 1 }  );

has '+launcher' => ( default => sub {"routes"} );

has '+startDependsOnServices' => (is => 'ro', default => sub { [] } );

has 'runningServices' => (is => 'rw', default => sub { 0 } );


=head2 start

start routes

=cut

sub startService {
    my ($self) = @_;
    manageStaticRoute(1);
    open(my $fh, '>>'.$self->pidFile);
    print $fh "-1";
    close($fh);
    return 1;
}


=head2 stop

stop routes

=cut

sub stop {
    my ($self) = @_;
    my $count = $self->runningServices;
    manageStaticRoute();
    unlink $self->pidFile;
    return 1;
}

=head2 isAlive

Check if routes is alive.
Since it's never really stopped than we check if the fake PID exists

=cut

sub isAlive {
    my ($self,$pid) = @_;
    my $result;
    $pid = $self->pid;
    my $route_exist = '';

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            $route_exist = $network;
        }
    }

    my $routes_applied = defined(pf_run("route | grep ".$route_exist));
    return (defined($pid) && $routes_applied);
}

=head2 manageStaticRoute

Add or remove static routes on the system

=cut

sub manageStaticRoute {
    my $add_Route = @_;
    my $logger = get_logger();

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            my $add_del = $add_Route ? 'add' : 'del';
            my $full_path = can_run('ip')
                or $logger->error("route is not installed! Can't add static routes to routed VLANs.");

            my $cmd = "sudo $full_path route $add_del $network" . "/". $net{'netmask'} . " via " . $net{'next_hop'};
            $cmd = untaint_chain($cmd);
            my @out = pf_run($cmd);
        }
    }
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
