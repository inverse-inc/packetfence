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
    @listen_ints
    %Config
);
use IPC::Cmd qw[can_run run];
use pf::constants qw($TRUE $FALSE);

use pf::nodecategory qw(nodecategory_view_all);

use POSIX qw(ceil);

extends 'pf::services::manager';

has '+name' => (default => sub { 'routes' } );

has '+shouldCheckup' => ( default => sub { 1 }  );

has '+launcher' => ( default => sub {"routes"} );

has 'runningServices' => (is => 'rw', default => sub { 0 } );

=head2 start

start routes

=cut

sub startService {
    my ($self) = @_;
    manageStaticRoute(1);
    return 1;
}


=head2 start

Wrapper around systemctl. systemctl should in turn call the actuall _start.

=cut

sub start {
    my ($self,$quick) = @_;
    system('sudo systemctl start packetfence-routes');
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

=head2 stop

Wrapper around systemctl. systemctl should in turn call the actual _stop.

=cut

sub stop {
    my ($self) = @_;
    system('sudo systemctl stop packetfence-routes');
    return 1;
}

=head2 _stop

stop routes (called from systemd)

=cut

sub _stop {
    my ($self) = @_;
    my $logger = get_logger();
    if ( $self->isAlive() ) {
        manageStaticRoute();
    }
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
    my $route_exist;

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            $route_exist = $network;
        }
    }
    my $routes_applied = $FALSE;
    $routes_applied = defined(pf_run("route | grep ".$route_exist)) if ($route_exist);
    $routes_applied = $TRUE if (-f "$install_dir/var/routes_applied");
    return (defined($pid) && $routes_applied);
}

=head2 pid

Override the default method to check pid since there really is no such thing for routes (it's not a process).

=cut

sub pid {
    my $self   = shift;
    my $result = `sudo systemctl show -p ActiveState packetfence-routes`;
    chomp $result;
    my $state = ( split( '=', $result ) )[1];
    if ( grep { $state eq $_ } qw( active activating deactivating ) ) {
        return -1;
    }
    else { return 0; }
}

=head2 manageStaticRoute

Add or remove static routes on the system

=cut

sub manageStaticRoute {
    my $add_Route = @_;
    my $logger = get_logger();
    my $full_path = can_run('ip');

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
        if (-f "$install_dir/var/virtual_routes.bak") {
            open (my $fh, "$install_dir/var/virtual_routes.bak");
            while (my $row = <$fh>) {
                chomp $row;
                my $cmd = untaint_chain($row);
                my @out = pf_run($cmd);
            }
            close $fh;
        }
        if (-f "$install_dir/var/routes_applied") {
           unlink("$install_dir/var/routes_applied");
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
        open ($fh, "+>$install_dir/var/virtual_routes.bak");

       foreach my $interface ( @listen_ints ) {
            my $cfg = $Config{"interface $interface"};
            next unless $cfg;
            my $current_interface = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );

            foreach my $network ( keys %ConfigNetworks ) {
                # shorter, more convenient local accessor
                my %net = %{$ConfigNetworks{$network}};
                my $current_network = NetAddr::IP->new( $network, $net{'netmask'} );
                my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
                if (defined($net{'next_hop'})) {
                    $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
                }
                if ($current_interface->contains($ip)) {
                    if ( isenabled($net{'dhcpd'}) ) {
                        if (isenabled($net{'split_network'})) {
                            my @categories = nodecategory_view_all();
                            my $count = @categories;
                            my $len = $current_network->masklen;
                            my $cidr = (ceil(log($count)/log(2)) + $len);
                            if ($cidr > 30) {
                                $logger->error("Can't split network");
                                return;
                            }
                            if ($net{'reg_network'}) {
                                my $cmd = "sudo $full_path addr del ".$net{'reg_network'}." dev $interface";
                                $cmd = untaint_chain($cmd);
                                print $fh $cmd."\n";
                                my @out = pf_run($cmd);
                                $cmd = "sudo $full_path addr add ".$net{'reg_network'}." dev $interface";
                                @out = pf_run($cmd);
                            }
                            my @sub_net = $current_network->split($cidr);
                            foreach my $net (@sub_net) {
                                my $role = pop @categories;
                                next unless $role->{'name'};
                                my $pool = $role->{'name'}.$interface;
                                my $pf_ip = $net + 1;
                                my $cmd = "sudo $full_path addr del ".$pf_ip->addr."/".$cidr." dev $interface";
                                $cmd = untaint_chain($cmd);
                                print $fh $cmd."\n";
                                my @out = pf_run($cmd);
                                $cmd = "sudo $full_path addr add ".$pf_ip->addr."/".$cidr." dev $interface";
                                @out = pf_run($cmd);
                                my $first = $net + 2;
                            }
                        }
                    }
                } else {
                    next;
                }
            }
        }
        close $fh;
        touch_file("$install_dir/var/routes_applied");
    }
}



sub isManaged {
    my ($self) = @_;

    my $route_exist = '';

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) || isenabled($net{'split_network'}) ) {
            return $TRUE;
        }
    }
    return $FALSE;
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
