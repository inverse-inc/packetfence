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
use CHI;
use Readonly;

# Internal libs
use pf::access_filter::dhcp;
use pf::client;
use pf::config qw(
    %ConfigNetworks
    %connection_type_to_str
    $INLINE
    %ConfigFirewallSSO
    %ConfigScan
);
use pf::config::util;
use pf::constants qw($TRUE);
use pf::constants::dhcp qw($DEFAULT_LEASE_LENGTH);
use pf::constants::IP qw($IPV4 $IPV6);
use pf::constants::firewallsso qw ($DHCP);
use pf::log;
use pf::node;
use pf::util;
use List::Util qw(any);

use Moose;

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config";

# pf::api::can_fork runs the api method in-process (and forks for :Fork
# methods like trigger_scan). pf::client::getClient would default to
# pf::api::jsonrpcclient inside the modern Go-driven pfqueue worker
# (sbin/pfqueue-backend doesn't setClient), so each notify() turns into an
# HTTPS POST to webservices — 5-7 round-trips per DHCP packet. Loading the
# class lazily avoids a compile-time circular dep with pf::api (pf::api
# loads this module, and pf::api::can_fork is already loaded by pf::task::api
# before any DHCP task runs).
has 'apiClient'    => (
    is      => 'ro',
    default => sub {
        require pf::api::can_fork;
        pf::api::can_fork->new;
    },
);
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
    is_dhcp         => 'is_dhcp',
);


# Local DHCP servers local cache
my @local_dhcp_servers_mac;
my @local_dhcp_servers_ip;

# Tracks when each (mac, ip, lease_length) last queued a firewallsso 'Update'.
# Process-local; with the hashed pfdhcplistener_external queue each MAC is
# pinned to one worker, so a per-process cache covers all packets for a given
# client. Entries are set with TTL = lease_length / 2 — the same half-lease
# cadence DHCP clients renew on — so the firewall session stays alive without
# enqueueing an Update on every renewal packet.
my $sso_refresh_hash = {};
my $sso_refresh_cache = CHI->new( driver => 'RawMemory', datastore => $sso_refresh_hash );

# Tracks the last DHCP signature observed per MAC (the IPv4 and DHCPv6
# fingerprint/vendor fields plus computername), so fingerbank_process is only
# enqueued when the device's DHCP fingerprint actually changes. Fingerbank
# classification is a pure function of those fields, so re-running it on
# identical input wastes a general-queue task per DHCP renewal. TTL mirrors
# the [storage fingerbank]
# expires_in (24h) — long enough to suppress renewal storms, short enough
# that updated Fingerbank signatures get re-applied within a day.
my $fingerbank_signature_hash = {};
my $fingerbank_signature_cache = CHI->new( driver => 'RawMemory', datastore => $fingerbank_signature_hash );
Readonly::Scalar my $FINGERBANK_SIGNATURE_TTL => 86400;


=head2 _get_local_dhcp_servers

Get the list of local (this server) IP and MAC address running DHCP server instances

Locally caches results on first run then returns from cache.

Returns an hash of arrays

=cut

sub _get_local_dhcp_servers {
    # Look for local DHCP servers by IP if not already existent in local cache and fill it up
    unless ( @local_dhcp_servers_ip ) {
        foreach my $network ( keys %NetworkConfig ) {
            if ($NetworkConfig{$network}{'dhcpd'} eq 'enabled') {
                push @local_dhcp_servers_ip, $NetworkConfig{$network}{'gateway'};
                push @local_dhcp_servers_ip, $NetworkConfig{$network}{'vip'} if ($NetworkConfig{$network}{'vip'});
                push @local_dhcp_servers_ip, split(',',$NetworkConfig{$network}{'cluster_ips'}) if ($NetworkConfig{$network}{'cluster_ips'});
            }
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
- Parking security_event
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
    if (any { pf::util::isenabled($_->{'sso_on_dhcp'}) } values %ConfigFirewallSSO ) {
        my $sso_mac     = $iptasks_arguments{'mac'};
        my $sso_ip      = $iptasks_arguments{'ip'};
        my $sso_timeout = $iptasks_arguments{'lease_length'} || $DEFAULT_LEASE_LENGTH;
        if ( $iptasks_arguments{'oldip'} && $iptasks_arguments{'oldip'} ne $sso_ip ) {
            $self->apiClient->notify( 'firewallsso', (method => 'Stop', mac => $sso_mac, ip => $iptasks_arguments{'oldip'}, timeout => undef, source => $DHCP) );
            $self->apiClient->notify( 'firewallsso', (method => 'Start', mac => $sso_mac, ip => $sso_ip, timeout => $sso_timeout, source => $DHCP) );
            # Start already established the session for the new IP with this
            # timeout, so arm the cache to skip the redundant Update below (and
            # subsequent renewals) until the next half-lease.
            $sso_refresh_cache->set("$sso_mac|$sso_ip|$sso_timeout", 1, int($sso_timeout / 2));
        }
        # Refresh the firewall session timeout at most once per half-lease.
        # Without this gate every DHCP renewal packet (one per client per
        # half-lease) queued a redundant general-queue task.
        my $sso_refresh_key = "$sso_mac|$sso_ip|$sso_timeout";
        unless ($sso_refresh_cache->get($sso_refresh_key)) {
            $self->apiClient->notify( 'firewallsso', (method => 'Update', mac => $sso_mac, ip => $sso_ip, timeout => $sso_timeout, source => $DHCP) );
            $sso_refresh_cache->set($sso_refresh_key, 1, int($sso_timeout / 2));
        }
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
        # Mirror the early-return in pf::api::trigger_scan: skip the
        # enqueue when no scan engines exist so we don't ship a task the
        # general-queue worker would immediately drop.
        if (scalar keys %ConfigScan) {
            $self->apiClient->notify('trigger_scan', %iptasks_arguments );
        }
    }

    # Parking security_event
    $self->checkForParking($iptasks_arguments{'mac'}, $iptasks_arguments{'ip'});
    if ( $iptasks_arguments{'oldmac'} && $iptasks_arguments{'oldmac'} ne $iptasks_arguments{'mac'} ) {
        # Remove the actions that were for the previous MAC address
        pf::parking::remove_parking_actions($iptasks_arguments{'oldmac'}, $iptasks_arguments{'ip'});
    }

    # IPlog
    if ( $iptasks_arguments{'ipversion'} eq $IPV4 ) {
        if (!$iptasks_arguments{'is_dhcp'}) {
            $self->apiClient->notify('update_ip4log', %iptasks_arguments);
        }
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
    unless ( (keys %$dhcp_filter_rule) > 0 ) {
        # Suppress fingerbank_process when the device's DHCP signature is
        # unchanged. Classification depends only on these fields, so re-running
        # on every renewal packet just wastes a general-queue task. The
        # signature must cover every field mapped into fingerbank_args that
        # influences classification, including the DHCPv6-derived ones, or a
        # change in only the DHCPv6 fingerprint/enterprise would be suppressed.
        my $mac = $fingerbank_args->{mac};
        my $signature = ($fingerbank_args->{dhcp_fingerprint} // '') . '|'
                      . ($fingerbank_args->{dhcp_vendor} // '') . '|'
                      . ($fingerbank_args->{computername} // '') . '|'
                      . ($fingerbank_args->{dhcp6_fingerprint} // '') . '|'
                      . ($fingerbank_args->{dhcp6_enterprise} // '');
        my $cached = $fingerbank_signature_cache->get($mac);
        if (!defined($cached) || $cached ne $signature) {
            $self->apiClient->notify('fingerbank_process', $mac);
            $fingerbank_signature_cache->set($mac, $signature, $FINGERBANK_SIGNATURE_TTL);
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
