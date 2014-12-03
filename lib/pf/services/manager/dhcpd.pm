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
use pf::constants;
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
    $tags{'omapi'} = omapi_section();
    $tags{'networks'} = '';
    $tags{'active'} = '';

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        if ($cfg->{'active_active_enabled'}) {
            my $master;
            ( $cfg->{'active_active_dhcpd_master'} ) ? $master = 'primary' : $master = 'secondary'; 
            my @active_members = '';
            if (defined($cfg->{'active_active_members'})) {
                @active_members = split(',',$cfg->{'active_active_members'});
            }
            my $members = join(',',grep { $_ ne $cfg->{'ip'} } @active_members);
            if ($members) {
                $tags{'active'} .= <<"EOT";
failover peer "$cfg->{'ip'}" {
  $master;
  address $cfg->{'ip'};
  port 647;
  peer address $members;
  peer port 647;
  max-response-delay 30;
  max-unacked-updates 10;
  load balance max seconds 3;
}

EOT
            }
        }
        my $net = Net::Netmask->new($cfg->{'ip'}, $cfg->{'mask'});
        my ($base,$mask) = ($net->base(), $net->mask());
        $direct_subnets{"subnet $base netmask $mask"} = $TRUE;
    }

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $ip = new NetAddr::IP::Lite clean_ip($net{'gateway'});
            if (defined($net{'next_hop'})) {
                $ip = new NetAddr::IP::Lite clean_ip($net{'next_hop'})
            }
            my $active = '0';
            foreach my $interface ( @listen_ints ) {
                my $cfg = $Config{"interface $interface"};
                my $current_network = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );
                if (isenabled($cfg->{'active_active_enabled'})) {
                    my @active_members = $cfg->{'ip'};
                    if (defined($cfg->{'active_active_members'})) {
                        @active_members = split(',',$cfg->{'active_active_members'});
                    }
                    my $members = join(',',grep { $_ ne $cfg->{'ip'} } @active_members);
                    if ($members) {
                        $active = $cfg->{'ip'} if $current_network->contains($ip);
                    }
                }
            }
            my $domain = sprintf("%s.%s", $net{'type'}, $Config{general}{domain});
            delete $direct_subnets{"subnet $network netmask $net{'netmask'}"};

            %net = _assign_defaults(%net);

            if ($active) {
                $tags{'networks'} .= <<"EOT";
subnet $network netmask $net{'netmask'} {
  option routers $net{'gateway'};
  option subnet-mask $net{'netmask'};
  option domain-name "$domain";
  option domain-name-servers $net{'dns'};
  pool {
      failover peer "$active";
      range $net{'dhcp_start'} $net{'dhcp_end'};
      default-lease-time $net{'dhcp_default_lease_time'};
      max-lease-time $net{'dhcp_max_lease_time'};
  }
}

EOT
            } else {

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


=head2 omapi_section

Generate the omapi section if it is defined

=cut

sub omapi_section {
    my $omapi_section = $Config{omapi};
    return '"# OMAPI is not enabled on this server' unless pf::config::is_omapi_enabled;
    my $section = "omapi-port $omapi_section->{port};\n";
    my $keyname = $omapi_section->{key_name};
    my $key_base64 = $omapi_section->{key_base64};
    if ( $keyname && $key_base64 ) {
        $section .=<<EOT;
key $keyname {
        algorithm HMAC-MD5;
        secret "$key_base64";
};
omapi-key $keyname;
EOT
    }

    return $section;
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
