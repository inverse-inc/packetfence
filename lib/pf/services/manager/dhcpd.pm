package pf::services::manager::dhcpd;
=head1 NAME

pf::services::manager::dhcpd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::dhcpd

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths;
use pf::config;
use pf::log;
use pf::services::dhcpd qw(generate_dhcpd_conf);
use File::Touch;
use IPC::Cmd qw[can_run run];

extends 'pf::services::manager';
with 'pf::services::manager::roles::pf_conf_service_managed';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';

has '+name' => (default => sub { 'dhcpd' } );

has '+launcher' => (default => sub { "sudo %1\$s -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf -pf $var_dir/run/dhcpd.pid " . join(" ", @listen_ints) } );


sub generateConfig {
    generate_dhcpd_conf();
}

sub preStartSetup {
    my ($self,$quick) = @_;
    $self->SUPER::preStartSetup($quick);
    my $leases_file = "$var_dir/dhcpd/dhcpd.leases";
    touch ($leases_file) unless -f $leases_file;
    manageStaticRoute(1);
    return 1;
}

sub stop {
    my ($self,$quick) = @_;
    $self->SUPER::stop($quick);
    manageStaticRoute();
}

sub manageStaticRoute {
    my $add_Route = @_;
    my $logger = get_logger;

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            my $add_del = $add_Route ? 'add' : 'del';
            my $full_path = can_run('route')
                or $logger->error("route is not installed! Can't add static routes to routed VLANs.");

            my $cmd = "sudo $full_path $add_del -net $network netmask " . $net{'netmask'} . " gw " . $net{'next_hop'};
            $cmd = untaint_chain($cmd);
            my @out = pf_run($cmd);
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

