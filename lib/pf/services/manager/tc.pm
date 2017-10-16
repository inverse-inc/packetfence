package pf::services::manager::tc;

=head1 NAME

pf::services::manager::tc

=cut

=head1 DESCRIPTION

Service manager for managing the traffic shaping

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($install_dir);

use pf::log;
use pf::util;

use pf::config qw(
    @internal_nets
    $management_network
    %ConfigNetworks
);
use pf::nodecategory;
use pf::iptables;

use IPC::Cmd qw[can_run run];
use pf::constants qw($TRUE $FALSE);

tie our %ConfigTrafficShaping, 'pfconfig::cached_hash', "config::TrafficShaping";

extends 'pf::services::manager';

has '+name' => (default => sub { 'tc' } );

has '+shouldCheckup' => ( default => sub { 1 }  );

has '+launcher' => ( default => sub {"tc"} );

has 'runningServices' => (is => 'rw', default => sub { 0 } );

=head2 start

start tc

=cut

sub startService {
    my ($self) = @_;
    manageTrafficShaping(1);
    return 1;
}


=head2 start

Wrapper around systemctl. systemctl should in turn call the actuall _start.

=cut

sub start {
    my ($self,$quick) = @_;
    system('sudo systemctl start packetfence-tc');
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
    system('sudo systemctl stop packetfence-tc');
    return 1;
}

=head2 _stop

stop routes (called from systemd)

=cut

sub _stop {
    my ($self) = @_;
    my $logger = get_logger();
    if ( $self->isAlive() ) {
        manageTrafficShaping();
    }
    return 1;
}


=head2 isAlive

Check if tc is alive.
Since it's never really stopped than we check if the fake PID exists

=cut

sub isAlive {
    my ($self,$pid) = @_;
    my $result;
    $pid = $self->pid;
    my $route_exist = '';
    my $full_path = can_run('tc');

    my @ints = split(',', pf::iptables::get_network_snat_interface());
    my @listen_interfaces = map {$_->tag("int")} @internal_nets, $management_network;

    my @interfaces = keys %{{map {($_ => 1)} (@ints, @listen_interfaces)}};

    foreach my $int ( @interfaces) {

        my $shaping_exist = "dev $int parent";
        return (defined($pid) && $TRUE) if (pf_run("sudo $full_path -p qdisc| grep -q '".$shaping_exist."'"))
    }
    return (defined($pid) && $FALSE);
}

=head2 pid

Override the default method to check pid since there really is no such thing for tc (it's not a process).

=cut

sub pid {
    my $self   = shift;
    my $result = `sudo systemctl show -p ActiveState packetfence-tc`;
    chomp $result;
    my $state = ( split( '=', $result ) )[1];
    if ( grep { $state eq $_ } qw( active activating deactivating ) ) {
        return -1;
    }
    else { return 0; }
}

=head2 manageTrafficShaping

Add or remove traffic shaping on the system

=cut

sub manageTrafficShaping {
    my $add_tc = @_;
    my $logger = get_logger();

    if (!$add_tc) {
        if (-f "$install_dir/var/traffic_shaping.bak") {
            open (my $fh, "$install_dir/var/traffic_shaping.bak");
            while (my $row = <$fh>) {
                chomp $row;
                my $cmd = untaint_chain($row);
                my @out = pf_run($cmd);
            }
            close $fh;
        }
    } else {
        open (my $fh, "+>$install_dir/var/traffic_shaping.bak");

        my @roles = pf::nodecategory::nodecategory_view_all;

        my @ints = split(',', pf::iptables::get_network_snat_interface());
        my @listen_interfaces = map {$_->tag("int")} @internal_nets, $management_network;

        my @interfaces = keys %{{map {($_ => 1)} (@ints, @listen_interfaces)}};

        my $i = 1;
        my %tags;
        my $full_path = can_run('tc');
        foreach my $int ( @interfaces) {
            my $cmd_remove = "sudo $full_path qdisc del dev $int root";
            print $fh $cmd_remove."\n";
            foreach my $network ( keys %ConfigNetworks ) {
                next if ( !pf::config::is_network_type_inline($network) );
                my $cmd = "sudo $full_path qdisc add dev $int root handle $i:0 htb default 1";
                $cmd = untaint_chain($cmd);
                my @out = pf_run($cmd);
                foreach my $role ( @roles ) {
                    if ($ConfigTrafficShaping{$role->{'name'}}->{'download'} && $ConfigTrafficShaping{$role->{'name'}}->{'upload'}) {
                        $cmd = "sudo $full_path class add dev $int parent $i:0 classid $i:$role->{'category_id'} htb rate $ConfigTrafficShaping{$role->{'name'}}->{'upload'}bps ceil $ConfigTrafficShaping{$role->{'name'}}->{'download'}bps";
                        $cmd = untaint_chain($cmd);
                        @out = pf_run($cmd);
                        $cmd = "sudo $full_path  qdisc add dev $int parent $i:$role->{'category_id'} sfq";
                        $cmd = untaint_chain($cmd);
                        @out = pf_run($cmd);
                     }
                }
            }
        }
        close $fh;
    }
}

sub isManaged {
    my ($self) = @_;

    my $route_exist = '';

    foreach my $network ( keys %ConfigNetworks ) {
        return $TRUE if pf::config::is_network_type_inline($network);
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
