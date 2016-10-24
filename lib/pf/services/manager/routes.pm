package pf::services::manager::routes;

=head1 NAME

pf::services::manager::routes

=cut

=head1 DESCRIPTION

Service manager for managing the routes

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
use pf::constants qw($TRUE $FALSE);

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
    my $logger = get_logger();
    my $result;
    $pid = $self->pid;
    my $route_exist = '';
    my $routes_applied = 0;
    my $layer3 = 0;

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            $layer3 ++;
            $route_exist = $network;
            $routes_applied = defined(pf_run("route | grep ".$route_exist));
        }
    }
    my $routes_applied = $FALSE;
    $routes_applied = defined(pf_run("route | grep ".$route_exist)) if ($route_exist);
    return (defined($pid) && $routes_applied);
}

=head2 manageStaticRoute

Add or remove static routes on the system

=cut

sub manageStaticRoute {
    my $add_Route = @_;
    my $logger = get_logger();

    if (!$add_Route) {
        if (-f "$install_dir/var/static_routes.bak") {
            open (my $fh, "$install_dir/var/static_routes.bak");
            while (my $row = <$fh>) {
                chomp $row;
                my $cmd = untaint_chain($row);
                my @out = pf_run($cmd);
            }
            close $fh;
        }
    } else {
        open (my $fh, "+>$install_dir/var/static_routes.bak");

        foreach my $network ( keys %ConfigNetworks ) {
            # shorter, more convenient local accessor
            my %net = %{$ConfigNetworks{$network}};

            if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
                my $full_path = can_run('ip')
                    or $logger->error("ip route is not installed! Can't add static routes to routed VLANs.");

                my $cmd = "sudo $full_path route add $network" . "/". $net{'netmask'} . " via " . $net{'next_hop'};
                my $cmd_remove = "sudo $full_path route del $network" . "/". $net{'netmask'} . " via " . $net{'next_hop'};
                $cmd = untaint_chain($cmd);
                my @out = pf_run($cmd);
                print $fh $cmd_remove."\n";
            }
        }
        close $fh;
    }
}

sub isManaged {
    my ($self) = @_;

    my $route_exist = '';

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            return $TRUE;
        }
    }
    return $FALSE;
}

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
