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
use File::Touch;
use IPC::Cmd qw[can_run run];
use POSIX;
use Net::Netmask;
use pf::config;
use pf::log;
use pf::util;

extends 'pf::services::manager';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';
has '+name' => (default => sub { 'dhcpd' } );

has '+launcher' => (default => sub { "sudo %1\$s -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf -pf $var_dir/run/dhcpd.pid " . join(" ", @listen_ints) } );

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();
    $logger->info("$package, $filename, $line");

    my %tags;
    my %direct_subnets;
    $tags{'template'} = "$conf_dir/dhcpd.conf";
    $tags{'networks'} = '';

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $net = Net::Netmask->new($cfg->{'ip'}, $cfg->{'mask'});
        my ($base,$mask) = ($net->base(), $net->mask());
        $direct_subnets{"subnet $base netmask $mask"} = $TRUE;
    }

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $domain = sprintf("%s.%s", $net{'type'}, $Config{general}{domain});
            delete $direct_subnets{"subnet $network netmask $net{'netmask'}"};

            %net = _assign_defaults(%net);

            $tags{'networks'} .= <<"EOT";
subnet $network netmask $net{'netmask'} {
  option routers $net{'gateway'};
  option subnet-mask $net{'netmask'};
  option domain-name "$domain";
  option domain-name-servers $net{'dns'};
  range $net{'dhcp_start'} $net{'dhcp_end'};
  default-lease-time $net{'dhcp_default_lease_time'};
  max-lease-time $net{'dhcp_max_lease_time'};
}

EOT
        }
    }

    # Generate empty subnets for every interface where we want dhcpd to
    # listen but no direct DHCP service is provided
    foreach my $network ( keys %direct_subnets ) {
            $tags{'networks'} .= <<"EOT";
$network {
}

EOT
    }

    parse_template( \%tags, "$conf_dir/dhcpd.conf", "$generated_conf_dir/dhcpd.conf" );
    return 1;
}

=head2 assign_defaults

Will replace all undef with default values.

=cut

# TODO should handle also dhcp_start and dhcp_end but it's more complex
#      requires network / netmask extrapolation
sub _assign_defaults {
    my (%net) = @_;

    $net{'dhcp_default_lease_time'} = 300 if (!defined($net{'dhcp_default_lease_time'}));
    $net{'dhcp_max_lease_time'} = 600 if (!defined($net{'dhcp_max_lease_time'}));

    return %net;
}

sub preStartSetup {
    my ($self,$quick) = @_;
    $self->SUPER::preStartSetup($quick);
    my $leases_file = "$var_dir/dhcpd/dhcpd.leases";
    mkdir "$var_dir/dhcpd" unless -d "$var_dir/dhcpd";
    touch ($leases_file) unless -f $leases_file;
    manageStaticRoute(1);
    return 1;
}

sub stop {
    my ($self,$quick) = @_;
    my $result = $self->SUPER::stop($quick);
    manageStaticRoute();
    return $result;
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

Copyright (C) 2005-2015 Inverse inc.

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

