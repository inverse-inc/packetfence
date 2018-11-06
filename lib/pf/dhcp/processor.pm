package pf::dhcp::processor;

=head1 NAME

pf::dhcp::processor

=cut

=head1 DESCRIPTION

Base class for processing DHCP packets

=cut

use strict;
use warnings;

# External libs
use Readonly;

# Internal libs
use pf::access_filter::dhcp;
use pf::client;
use pf::config qw(
    %ConfigNetworks
    %connection_type_to_str
    $INLINE
);
use pf::config::util;
use pf::constants::dhcp qw($DEFAULT_LEASE_LENGTH);
use pf::constants::IP qw($IPV4 $IPV6);
use pf::log;
use pf::node;
use pf::util;

use Moose;


has 'apiClient'    => (is => 'ro', default => sub { pf::client::getClient });
has 'filterEngine' => (is => 'rw', default => sub { pf::access_filter::dhcp->new });


# Fingerbank processing arguments mapping
# Only arguments listed (mapped) below will be processed
Readonly::Hash my %FINGERBANK_ARGUMENTS_MAP => (
    client_mac              => 'mac',
    client_ip               => 'ip',
    client_hostname         => 'computername',
    ipv4_requested_options  => 'dhcp_fingerprint',
    ipv4_vendor             => 'dhcp_vendor',
    ipv6_requested_options  => 'dhcp6_fingerprint',
    ipv6_vendor             => 'dhcp_vendor',
    ipv6_enterprise_number  => 'dhcp6_enterprise',
);

# IP tasks processing arguments mapping
# Only arguments listed (mapped) below will be processed
Readonly::Hash my %IPTASKS_ARGUMENTS_MAP => (
    client_mac      => 'mac',
    client_ip       => 'ip',
    lease_length    => 'lease_length',
    ip_type         => 'ip_type',
);


# Local DHCP servers local cache
my @local_dhcp_servers_mac;
my @local_dhcp_servers_ip;


=head2 _get_local_dhcp_servers

Get the list of local (this server) IP and MAC address running DHCP server instances

Locally caches results on first run then returns from cache.

Returns an hash of arrays

=cut

sub _get_local_dhcp_servers {
    # Look for local DHCP servers by IP if not already existent in local cache and fill it up
    unless ( @local_dhcp_servers_ip ) {
        foreach my $network ( keys %ConfigNetworks ) {
            push @local_dhcp_servers_ip, $ConfigNetworks{$network}{'gateway'} if ($ConfigNetworks{$network}{'dhcpd'} eq 'enabled');
        }
    }

    # Look for local DHCP servers by MAC if not already existent in local cache and fill it up
    unless ( @local_dhcp_servers_mac ) {
        @local_dhcp_servers_mac = pf::config::util::get_internal_macs();
    }

    # Return an hash of arrays for both the IPs and the MACs
    return ( ip => [@local_dhcp_servers_ip], mac => [@local_dhcp_servers_mac] );
}


=head2 processIPTasks

Different IP based tasks processing part of the DHCP flow

- Firewall SSO
- Inline enforcement
- Conformity scan
- Parking violation
- iplog

=cut

sub processIPTasks {
    my ( $self, %arguments ) = @_;
    my $logger = pf::log::get_logger();

    # Parse arguments
    my %iptasks_arguments = ();
    foreach my $key ( keys %arguments ) {
        if ( exists $IPTASKS_ARGUMENTS_MAP{$key} ) {
            $iptasks_arguments{$IPTASKS_ARGUMENTS_MAP{$key}} = $arguments{$key};
        }
    }

    $self->preProcessIPTasks(\%iptasks_arguments);

    # update last_seen of MAC address as some activity from it has been seen
    pf::node::node_update_last_seen($iptasks_arguments{'mac'});

    # Firewall SSO
    if (isenabled($pf::config::Config{advanced}{sso_on_dhcp})) {
        if ( $iptasks_arguments{'oldip'} && $iptasks_arguments{'oldip'} ne $iptasks_arguments{'ip'} ) {
            $self->apiClient->notify( 'firewallsso', (method => 'Stop', mac => $iptasks_arguments{'mac'}, ip => $iptasks_arguments{'oldip'}, timeout => undef) );
            $self->apiClient->notify( 'firewallsso', (method => 'Start', mac => $iptasks_arguments{'mac'}, ip => $iptasks_arguments{'ip'}, timeout => $iptasks_arguments{'lease_length'} || $DEFAULT_LEASE_LENGTH) );
        }
        $self->apiClient->notify( 'firewallsso', (method => 'Update', mac => $iptasks_arguments{'mac'}, ip => $iptasks_arguments{'ip'}, timeout => $iptasks_arguments{'lease_length'} || $DEFAULT_LEASE_LENGTH) );
    }

    # Inline enforcement
    # 2017.03.20 - dwuelfrath@inverse.ca - There is currently no ipv6 support for inline enforcement. Remove the condition once "resolved"
    unless ( $iptasks_arguments{'ipversion'} eq $IPV6 ) {
        if ( $iptasks_arguments{'oldip'} && $iptasks_arguments{'oldip'} ne $iptasks_arguments{'ip'} ) {
            my $node_view = node_view($iptasks_arguments{'mac'});
            my $last_connection_type = $node_view->{'last_connection_type'};
            $self->apiClient->notify('ipset_node_update', $iptasks_arguments{'oldip'}, $iptasks_arguments{'ip'}, $iptasks_arguments{'mac'}) if (defined $last_connection_type && $last_connection_type eq $connection_type_to_str{$INLINE});
        }
    }

    # Conformity scan
    # 2017.03.20 - dwuelfrath@inverse.ca - There is currently no ipv6 support for conformity scan. Remove the condition once "resolved"
    unless ( $iptasks_arguments{'ipversion'} eq $IPV6 ) {
        $self->apiClient->notify('trigger_scan', %iptasks_arguments );
    }

    # Parking violation
    $self->checkForParking($iptasks_arguments{'mac'}, $iptasks_arguments{'ip'});
    if ( $iptasks_arguments{'oldmac'} && $iptasks_arguments{'oldmac'} ne $iptasks_arguments{'mac'} ) {
        # Remove the actions that were for the previous MAC address
        pf::parking::remove_parking_actions($iptasks_arguments{'oldmac'}, $iptasks_arguments{'ip'});
    }

    # IPlog
    if ( $iptasks_arguments{'ipversion'} eq $IPV4 ) {
        $self->apiClient->notify('update_ip4log', %iptasks_arguments);
    } elsif ( $iptasks_arguments{'ipversion'} eq $IPV6 ) {
        $self->apiClient->notify('update_ip6log', %iptasks_arguments);
    }
}


=head2 processFingerbank

Fingerbank processing part of the DHCP flow

=cut

sub processFingerbank {
    my ( $self, $attributes ) = @_;
    my $logger = pf::log::get_logger();

    my $fingerbank_args = {};
    foreach my $key ( keys %{$attributes} ) {
        if ( exists $FINGERBANK_ARGUMENTS_MAP{$key} ) {
            if ( ref($attributes->{$key}) eq 'ARRAY' ) {
                $fingerbank_args->{$FINGERBANK_ARGUMENTS_MAP{$key}} = join ',', @{$attributes->{$key}};
            }
            else {
                $fingerbank_args->{$FINGERBANK_ARGUMENTS_MAP{$key}} = $attributes->{$key};
            }
        }
    }

    # DHCP filters (Fingerbank scope)
    # If there is a match, we override Fingerbank call
    my $dhcp_filter_rule = $self->filterEngine->filter('Fingerbank', $fingerbank_args);
    unless ( $dhcp_filter_rule ) {
        $self->apiClient->notify('fingerbank_process', $fingerbank_args->{mac});
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
