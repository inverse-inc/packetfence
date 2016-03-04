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
use pf::constants;
use NetAddr::IP;
use pf::config;
use pf::log;
use pf::util;
use pf::cluster;

extends 'pf::services::manager';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';
has '+name' => (default => sub { 'dhcpd' } );

has '+launcher' => (default => sub { "sudo %1\$s -q -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf -pf $var_dir/run/dhcpd.pid " . join(" ", @listen_ints) } );

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

    my $failover_activated = 0;

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $master = 'secondary';
        $master = 'primary' if ( pf::cluster::is_dhcpd_primary() );
        my $members = pf::cluster::dhcpd_peer($interface);
        if (defined($members)) {
            $failover_activated = 1;
            my $ip = NetAddr::IP::Lite->new($cfg->{'ip'}, $cfg->{'mask'});
            my $net = $ip->network();
            $tags{'active'} .= <<"EOT";
failover peer "$net" {
  $master;
  address $cfg->{'ip'};
  port 647;
  peer address $members;
  peer port 647;
  max-response-delay 30;
  max-unacked-updates 10;
  load balance max seconds 3;
EOT
            if ($master eq 'primary') {
                $tags{'active'} .= <<"EOT";
  mclt 1800;
  split 128;
}
EOT
            } else {
                $tags{'active'} .= <<"EOT";
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
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
            }
            my $active = '0';
            my $dns ='0';
            if($cluster_enabled){
                foreach my $interface ( @listen_ints ) {
                    my $cfg = $Config{"interface $interface"};
                    my $current_network = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );
                    my $members;
                    # If we use passthroughs we only use management for DNS server as ipset sessions are not replicated
                    if( isenabled($Config{active_active}{dns_on_vip_only}) || isenabled($Config{trapping}{passthrough}) ){
                        $members = pf::cluster::cluster_ip($interface);
                    }
                    else {
                        my @active_members = values %{pf::cluster::members_ips($interface)};
                        $members = join(',',@active_members);
                    }
                    if ($members) {
                        if ($current_network->contains($ip)) {
                            $dns = $members;
                        $active = defined($net{next_hop}) ?
                                 NetAddr::IP::Lite->new($net{'next_hop'}, $cfg->{'mask'}) :
                                 NetAddr::IP::Lite->new($cfg->{'ip'}, $cfg->{'mask'});
                        }
                    }
                }
            }
            my $domain = sprintf("%s.%s", $net{'type'}, $Config{general}{domain});
            delete $direct_subnets{"subnet $network netmask $net{'netmask'}"};

            %net = _assign_defaults(%net);
            $dns = $net{'dns'} if (!$dns);
            if ($active) {
                my $peer = $active->network();
                $tags{'networks'} .= <<"EOT";
subnet $network netmask $net{'netmask'} {
  option routers $net{'gateway'};
  option subnet-mask $net{'netmask'};
  option domain-name "$net{'domain-name'}";
  option domain-name-servers $dns;
  pool {
EOT

                if($failover_activated){
                    $tags{'networks'} .= "failover peer \"$peer\";\n"
                }

              $tags{'networks'} .= <<"EOT";
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
  option domain-name "$net{'domain-name'}";
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

    $tags{parking_lease_length} = $Config{parking}{lease_length};

    parse_template( \%tags, "$conf_dir/dhcpd.conf", "$generated_conf_dir/dhcpd.conf" );
    return 1;
}


=head2 omapi_section

Generate the omapi section if it is defined

=cut

sub omapi_section {
    return '# OMAPI is not enabled on this server' unless $Config{'omapi'}{'host'} eq "localhost";
    return '# OMAPI is enabled on this server but missing configuration parameter(s)' unless pf::config::is_omapi_configured;

    my $port        = $Config{'omapi'}{'port'};
    my $key_name    = $Config{'omapi'}{'key_name'};
    my $key_base64  = $Config{'omapi'}{'key_base64'};

    my $section = <<EOT;
# OMAPI for IP <-> MAC lookup
omapi-port $port;
key $key_name {
    algorithm HMAC-MD5;
    secret "$key_base64";
};
omapi-key $key_name;
EOT

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
    my $logger = get_logger();

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

sub isManaged {
    my ($self) = @_;
    my $logger = get_logger();
    if($cluster_enabled && !pf::cluster::should_offer_dhcp()){
        $logger->info("This server cannot offer dhcp according to pf::cluster");
        return 0;
    }
    return $self->SUPER::isManaged();
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
