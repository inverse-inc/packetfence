package pf::ipset;

=head1 NAME

pf::ipset - module for ipset tables management.

=cut

=head1 DESCRIPTION

pf::ipset contains the functions necessary to manipulate the
ipset tables used when using PacketFence in ARP or DHCP mode.

=cut

use strict;
use warnings;

use base ('pf::iptables');
use Log::Log4perl;
use Readonly;
use NetAddr::IP;


use pf::class qw(class_view_all class_trappable);
use pf::config;
use pf::node qw(nodes_registered_not_violators);
use pf::util;
use pf::violation qw(violation_view_open_uniq violation_count);
use pf::iplog;

Readonly my $FW_TABLE_FILTER => 'filter';
Readonly my $FW_TABLE_MANGLE => 'mangle';
Readonly my $FW_TABLE_NAT => 'nat';
Readonly my $FW_FILTER_INPUT_INT_VLAN => 'input-internal-vlan-if';
Readonly my $FW_FILTER_INPUT_INT_INLINE => 'input-internal-inline-if';
Readonly my $FW_FILTER_INPUT_MGMT => 'input-management-if';
Readonly my $FW_FILTER_INPUT_INT_HA => 'input-highavailability-if';
Readonly my $FW_FILTER_FORWARD_INT_INLINE => 'forward-internal-inline-if';
Readonly my $FW_PREROUTING_INT_INLINE => 'prerouting-int-inline-if';
Readonly my $FW_POSTROUTING_INT_INLINE => 'postrouting-int-inline-if';

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut
sub iptables_generate {
    my $self = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');

    # init ipset tables
    $logger->warn("We are using IPSET");
    my $cmd = "sudo ipset --destroy";
    my $out = `$cmd`;
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            if ($IPSET_VERSION > 4) {
                $cmd = "sudo ipset --create pfsession_$IPTABLES_MARK\_$network bitmap:ip,mac range $network/$inline_obj->{BITS}";
                $out = `$cmd`;
            }
            else {
                $cmd = "sudo ipset --create pfsession_$IPTABLES_MARK\_$network macipmap --network $network/$inline_obj->{BITS}";
                $out = `$cmd`;
            }
        }
    }
    $self->SUPER::iptables_generate();
}


=item generate_mangle_rules

Packet marking will traverse all the rules so the order in which packets are marked is rather important.
The last mark will be the one having an effect.

=cut
sub generate_mangle_rules {
    my $self =@_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $mangle_rules = '';

    # pfdhcplistener in most cases will be enforcing access
    # however we insert these marks on startup in case PacketFence is restarted

    # default catch all: mark unreg
    $mangle_rules .= "-A $FW_PREROUTING_INT_INLINE --jump MARK --set-mark 0x$IPTABLES_MARK_UNREG\n";
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            $mangle_rules .= "-A $FW_PREROUTING_INT_INLINE -m set --match-set pfsession_$IPTABLES_MARK\_$network src,src " .
            "--jump MARK --set-mark 0x$IPTABLES_MARK\n"
            ;
        }
    }

    # mark registered nodes that should not be isolated
    # TODO performance: mark all *inline* registered users only
    my @registered = nodes_registered_not_violators();
    foreach my $row (@registered) {
        foreach my $network ( keys %ConfigNetworks ) {
            next if ( !pf::config::is_network_type_inline($network) );
            my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
            my $mac = $row->{'mac'};
            my $iplog = mac2ip($mac);
            if (defined $iplog) {
                my $ip = new NetAddr::IP::Lite clean_ip($iplog);
                if ($net_addr->contains($ip)) {
                    my $cmd = "sudo ipset --add pfsession_$IPTABLES_MARK_REG\_$network $iplog,$mac";
                    my $out = `$cmd`;
                }
            }
        }
    }

    # mark all open violations
    # TODO performance: only those whose's last connection_type is inline?
    my @macarray = violation_view_open_uniq();
    if ( $macarray[0] ) {
        foreach my $row (@macarray) {
            foreach my $network ( keys %ConfigNetworks ) {
                next if ( !pf::config::is_network_type_inline($network) );
                my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
                my $mac = $row->{'mac'};
                my $iplog = mac2ip($mac);
                if (defined $iplog) {
                    my $ip = new NetAddr::IP::Lite clean_ip($iplog);
                    if ($net_addr->contains($ip)) {
                        my $cmd = "sudo ipset --add pfsession_$IPTABLES_MARK_ISOLATION\_$network $iplog,$mac";
                        my $out = `$cmd`;
                    }
                }
            }
        }
    }

    # mark whitelisted users
    # TODO whitelist concept on it's way to the graveyard
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'whitelist'} ) ) {
        $mangle_rules .=
            "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac --jump MARK --set-mark 0x$IPTABLES_MARK_REG\n"
        ;
    }

    # mark blacklisted users
    # TODO blacklist concept on it's way to the graveyard
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'blacklist'} ) ) {
        $mangle_rules .=
            "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac --jump MARK --set-mark $IPTABLES_MARK_ISOLATION\n"
        ;
    }

    return $mangle_rules;
}


sub iptables_mark_node {
    my ( $self, $mac, $mark ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = mac2ip($mac);
        if (defined $iplog) {
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);
            if ($net_addr->contains($ip)) {
                my $cmd = "sudo ipset --add pfsession_$mark\_$network $iplog,$mac";
                my $out = `$cmd`;
            }
        }
        else {
            $logger->error("Unable to mark mac $mac");
            return;
        }
    }
    return (1);
}

sub iptables_unmark_node {
    my ( $self, $mac, $mark ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = mac2ip($mac);
        if (defined $iplog) {
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);
            if ($net_addr->contains($ip)) {
                my $cmd = "sudo ipset --del pfsession_$mark\_$network $iplog,$mac";
                my $out = `$cmd`;
            }
        }
        else {
            $logger->error("Unable to unmark mac $mac");
            return;
        }
    }
    return (1);
}

=item get_mangle_mark_for_mac

Fetches the current mangle mark for a given mark.
Useful to re-evaluate what to do with a given node who's state changed.

Returns IPTABLES MARK constant ($IPTABLES_MARK_...) or undef on failure.

=cut
# TODO migrate to IPTables::Interface (to get rid of IPTables::ChainMgr) once it supports fetching iptables info
sub get_mangle_mark_for_mac {
    my ( $self, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = mac2ip($mac);
        if (defined $iplog) {
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);
            if ($net_addr->contains($ip)) {
                foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
                    my $cmd = "sudo ipset --test pfsession_$IPTABLES_MARK\_$network $iplog,$mac";
                    my @out = `$cmd 2>&1`;
                    if (!($out[0] =~ m/NOT/i)) {
                        return $IPTABLES_MARK;
                    }
                }
            }
        }
        else {
            $logger->error("Unable to list iptables mangle table: $!");
            return;
        }
    }
 return $IPTABLES_MARK_UNREG;
}


=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
