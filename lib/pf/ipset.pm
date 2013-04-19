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
use pf::node qw(nodes_registered_not_violators node_view node_deregister $STATUS_REGISTERED);
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
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    # init ipset tables
    $logger->warn("We are using IPSET");
    #Flush mangle table to permit ipset destroy
    $self->iptables_flush_mangle;
    my $cmd = "LANG=C sudo ipset --destroy";
    my @lines = pf_run($cmd);
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            if ($IPSET_VERSION > 4) {
                $cmd = "LANG=C sudo ipset --create pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network bitmap:ip,mac range $network/$inline_obj->{BITS} 2>&1";
                 my @lines  = pf_run($cmd);
            }
            else {
                $cmd = "LANG=C sudo ipset --create pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network macipmap --network $network/$inline_obj->{BITS} 2>&1";
                my @lines  = pf_run($cmd);
            }
        }
    }
    # OAuth
    my $google_enabled = $guest_self_registration{$SELFREG_MODE_GOOGLE};
    my $facebook_enabled = $guest_self_registration{$SELFREG_MODE_FACEBOOK};
    my $github_enabled = $guest_self_registration{$SELFREG_MODE_GITHUB};

    if ($google_enabled || $facebook_enabled || $github_enabled) {
        if ($IPSET_VERSION > 4) {
            $cmd = "LANG=C sudo ipset --create pfsession_oauth hash:ip,port 2>&1";
             my @lines  = pf_run($cmd);
        }
        else {
            $logger->warn("We doesnt support ipset under version 4");
        }
    }
    $self->SUPER::iptables_generate();
}


=item generate_mangle_rules

Packet marking will traverse all the rules so the order in which packets are marked is rather important.
The last mark will be the one having an effect.

=cut
sub generate_mangle_rules {
    my ($self) =@_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $mangle_rules = '';

    # pfdhcplistener in most cases will be enforcing access
    # however we insert these marks on startup in case PacketFence is restarted

    # default catch all: mark unreg
    $mangle_rules .= "-A $FW_PREROUTING_INT_INLINE --jump MARK --set-mark 0x$IPTABLES_MARK_UNREG\n";
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            $mangle_rules .= "-A $FW_PREROUTING_INT_INLINE -m set --match-set pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network src,src " .
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
                    my $cmd = "LANG=C sudo ipset --add pfsession_$mark_type_to_str{$IPTABLES_MARK_REG}\_$network $iplog,$mac 2>&1";
                    my @lines  = pf_run($cmd);
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
                        my $cmd = "LANG=C sudo ipset --add pfsession_$mark_type_to_str{$IPTABLES_MARK_ISOLATION}\_$network $iplog,$mac 2>&1";
                        my @lines  = pf_run($cmd);
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

    return $mangle_rules;
}


sub iptables_mark_node {
    my ( $self, $mac, $mark, $newip ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    foreach my $network ( keys %ConfigNetworks ) {

        next if ( !pf::config::is_network_type_inline($network) );

        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = $newip || mac2ip($mac);

        if (defined $iplog) {
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);
            if ($net_addr->contains($ip)) {
                #Prevent double entries in ipset
                $self->ipset_remove_ip($iplog, $mark, $network);
                my $cmd = "LANG=C sudo ipset --add pfsession_$mark_type_to_str{$mark}\_$network $iplog,$mac 2>&1";
                my @lines  = pf_run($cmd);
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
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $ipset = $self->get_ip_from_ipset_by_mac($mac, $mark);
    while ( my ($network, $iplist) = each(%$ipset) ) {
        if (defined($iplist)) {
            foreach my $IP ( split( ',', $iplist ) ) {
                my $cmd = "LANG=C sudo ipset --del pfsession_$mark_type_to_str{$mark}\_$network $IP 2>&1";
                my @lines  = pf_run($cmd);
            }
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

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $_EXIT_CODE_EXISTS = 1;

    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );

        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = mac2ip($mac);

        if (defined $iplog) {
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);

            if ($net_addr->contains($ip)) {
                foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
                    
                    my $cmd = "LANG=C sudo ipset --test pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network $iplog,$mac 2>&1";
                    my @out = pf_run($cmd, , accepted_exit_status => [ $_EXIT_CODE_EXISTS ]);

                    if (defined($out[0]) && !($out[0] =~ m/NOT/i)) {
                        return $IPTABLES_MARK;
                    }
                }
            }
        }
        else {
            $logger->error("Unable to list iptables mangle table: $!");
            return $IPTABLES_MARK_UNREG;
        }
    }
 return $IPTABLES_MARK_UNREG;
}

=item ipset_remove_ip

Remove ip from ipset session

=cut

sub ipset_remove_ip {
    my ( $self, $ip, $mark, $network) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($cmd, $out);
    if ($IPSET_VERSION > 4) {
        $cmd = "LANG=C sudo ipset --list pfsession_$mark_type_to_str{$mark}\_$network 2>&1";
        $out  = pf_run($cmd);
    }
    else {
       $cmd = "LANG=C sudo ipset -n --list pfsession_$mark_type_to_str{$mark}\_$network 2>&1";
       $out  = pf_run($cmd);
    }
    my @lines = split "\n+", $out;

    foreach my $line (@lines) {

        # skip emtpy lines from ipset list
        next if $line =~ m/^\s*$/;

        # skip comment lines from ipset list
        next if $line =~ m/:\s|:\Z/;
        if ($line =~ m/^\s* $ip , .* \s* $/ix) {
            $cmd = "LANG=C sudo ipset --del pfsession_$mark_type_to_str{$mark}\_$network $ip 2>&1";
            $out = pf_run($cmd);
        }
    }
}

=item get_ip_from_ipset_by_mac

Fetches all the ip address from ipset by mac address

=cut

sub get_ip_from_ipset_by_mac {
    my ( $self, $mac, $mark) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $session = {};
    my ($cmd, $out);
    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $ip;
        if ($IPSET_VERSION > 4) {
            $cmd = "LANG=C sudo ipset --list pfsession_$mark_type_to_str{$mark}\_$network 2>&1";
            $out = pf_run($cmd);
        }
        else {
            $cmd = "LANG=C sudo ipset -n --list pfsession_$mark_type_to_str{$mark}\_$network 2>&1";
            $out =  pf_run($cmd);
        }
        my @lines = split "\n+", $out;

        # ipv4 address in quad decimal
        my $ip_quad_dec_rx = qr(\d{1,3} \. \d{1,3} \. \d{1,3} \. \d{1,3})x;

        foreach my $line (@lines) {

            # skip emtpy lines from ipset list
            next if $line =~ m/^\s*$/;

            # skip comment lines from ipset list
            next if $line =~ m/:\s|:\Z/;

            if ($line =~ m/^\s* ($ip_quad_dec_rx) , $mac \s* $/ix) {
                $ip  .= $1.",";
                unless ( $ip && $mac ) {
                    $logger->warn("Couldn't parse line: $line");
                    next;
                }
            }
        }
        $session->{$network} = $ip;
    }
    return $session;
}

=item update_ipset

Update session when the ip address change

=cut

sub update_node {
    my ( $self, $oldip, $srcip, $srcmac ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $view_mac = node_view($srcmac);
    my $src_ip = new NetAddr::IP::Lite clean_ip($srcip);
    my $old_ip = new NetAddr::IP::Lite clean_ip($oldip);
    if ($view_mac->{'last_connection_type'} eq $connection_type_to_str{$INLINE}) {
        my $mark = $self->get_mangle_mark_for_mac($srcmac);
        foreach my $network ( keys %ConfigNetworks ) {
            next if ( !pf::config::is_network_type_inline($network) );

            my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});

            if ($net_addr->contains($src_ip) && $net_addr->contains($old_ip) ) {
                if (defined($mark)) {
                    $self->iptables_unmark_node($srcmac,$mark);
                    $self->iptables_mark_node($srcmac,$mark,$srcip);
                    return (1);
                }
            }
            if ($net_addr->contains($src_ip) xor $net_addr->contains($old_ip) ) {
                if (isenabled($Config{'inline'}{'should_reauth_on_vlan_change'})) {
                    $logger->info("Unreg $srcmac because the inline vlan change");
                    $self->iptables_unmark_node($srcmac,$mark);
                    node_deregister($srcmac);
                    return (1);
                }
                else {
                    if (defined($mark)) {
                        $logger->info("Update ipset session because $srcmac change vlan");
                        $self->iptables_unmark_node($srcmac,$mark);
                        $self->iptables_mark_node($srcmac,$mark,$srcip);
                        return (1);
                    }
                }
            }

        }
    }
    return (1);
}

=item iptables_flush_mangle

Flush mangle table

=cut

sub iptables_flush_mangle {
    my ($self, $restore_file) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->info( "flushing iptables" );
    pf_run("/sbin/iptables -t mangle -F");
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
