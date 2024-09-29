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

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iptables_generate
        iptables_mark_node iptables_unmark_node get_mangle_mark_for_mac update_mark
    );
}

use pf::log;
use Readonly;
use NetAddr::IP;

use pf::config qw(
    %connection_type_to_str
    %Config
    %ConfigNetworks
    $IPTABLES_MARK_ISOLATION
    $IPTABLES_MARK_REG
    $IPTABLES_MARK_UNREG
    %mark_type_to_str
    $NET_TYPE_INLINE_L3
    $SELFREG_MODE_GITHUB
    $SELFREG_MODE_GOOGLE
    $SELFREG_MODE_FACEBOOK
    $INLINE
    $management_network
    @internal_nets
    is_type_inline
);
use pf::node qw(nodes_registered_not_violators node_view node_deregister $STATUS_REGISTERED);
use pf::nodecategory;
use pf::util;
use pf::ip4log;
use pf::authentication;
use pf::constants::node qw($STATUS_UNREGISTERED);
use pf::api::unifiedapiclient;
use pf::config::cluster;
use pf::constants;
use pf::config::cluster;
use pf::file_paths qw($generated_conf_dir $conf_dir);
use pf::security_event qw(security_event_view_open_uniq security_event_count);
use pf::authentication;
use pf::cluster;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::Domain;

use File::Slurp qw(read_file);
use IO::Interface::Simple;
use List::MoreUtils qw(uniq);
use URI ();

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

=item new

Constructor

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::ipset object");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

sub iptables_generate {
    my ($self) = @_;
    my $logger = get_logger();
    # init ipset tables
    $logger->warn("We are using IPSET");
    #Flush mangle table to permit ipset destroy
    $self->iptables_flush_mangle;
    my @lines = safe_pf_run(qw(sudo ipset --destroy));
    my @roles = pf::nodecategory::nodecategory_view_all;

    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );

        # Create an ipset for each PacketFence defined role in both inline L2 and L3 cases
        # Using the role ID in the name instead of the role name due to ipset name length constraint (max32)
        my $timeout;
        if ($ConfigNetworks{$network}{'dhcp_default_lease_time'} < 60 ) {
            $timeout = 120;
        } else {
            $timeout = $ConfigNetworks{$network}{'dhcp_default_lease_time'} + 60;
        }
        foreach my $role ( @roles ) {
            my @cmds;
            if ( $ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i ) {
                @cmds = (qw(sudo ipset --create), "PF-iL3_ID$role->{'category_id'}_$network", qw(bitmap:ip range), "$network/$inline_obj->{BITS}", "timeout", $timeout);
            } else {
                @cmds = (qw(sudo ipset --create), "PF-iL2_ID$role->{'category_id'}_$network", qw(bitmap:ip range), "$network/$inline_obj->{BITS}", "timeout", $timeout);
            }
            my @lines  = safe_pf_run(@cmds);
        }

        foreach my $IPTABLES_MARK ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            my @cmds;
            if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
                @cmds = (qw(sudo ipset --create), "pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network", qw(bitmap:ip range) ,"$network/$inline_obj->{BITS}", "timeout", $timeout);
            } else {
                if (isenabled($ConfigNetworks{$network}{'split_network'}) && ($IPTABLES_MARK eq $IPTABLES_MARK_UNREG) ) {
                    @cmds = (qw(sudo ipset --create), "pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network", 'bitmap:ip,mac', 'range', "$network/$inline_obj->{BITS}", "timeout", 120 );
                } else {
                    @cmds = (qw(sudo ipset --create), "pfsession_$mark_type_to_str{$IPTABLES_MARK}\_$network", 'bitmap:ip', 'range', "$network/$inline_obj->{BITS}", "timeout", $timeout );
                }
            }
            my @lines  = safe_pf_run(@cmds);
        }
    }
    # OAuth and passthrough
    my $google_enabled = $guest_self_registration{$SELFREG_MODE_GOOGLE};
    my $facebook_enabled = $guest_self_registration{$SELFREG_MODE_FACEBOOK};
    my $github_enabled = $guest_self_registration{$SELFREG_MODE_GITHUB};
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($google_enabled || $facebook_enabled || $github_enabled || $passthrough_enabled) {
        my @lines  = safe_pf_run(qw(sudo ipset --create pfsession_passthrough),  'hash:ip,port');
        @lines  = safe_pf_run(qw(sudo ipset --create pfsession_isol_passthrough), 'hash:ip,port');
    }
}


sub iptables_mark_node {
    my ( $self, $mac, $mark, $newip ) = @_;
    my $logger = get_logger();

    foreach my $network ( keys %ConfigNetworks ) {

        next if ( !pf::config::is_network_type_inline($network) );

        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $iplog = $newip || pf::ip4log::mac2ip($mac);

        if (defined $iplog) {
            my $node_info = pf::node::node_view($mac);
            my $role_id = $node_info->{'category_id'} // "0";
            my $ip = new NetAddr::IP::Lite clean_ip($iplog);
            if ($net_addr->contains($ip)) {

                if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
                    call_ipsetd("/ipset/mark_layer3?local=0",{
                        "network" => $network,
                        "type"    => $mark_type_to_str{$mark},
                        "role_id" => "".$role_id,
                        "ip"      => $iplog
                    });
                } else {
                    call_ipsetd("/ipset/mark_layer2?local=0",{
                        "network" => $network,
                        "type"    => $mark_type_to_str{$mark},
                        "role_id" => "".$role_id,
                        "ip"      => $iplog,
                        "mac"     => $mac
                    });
                }
            }
        } else {
            $logger->error("Unable to mark mac $mac");
            return;
        }
    }
    return (1);
}

sub iptables_unmark_node {
    my ( $self, $mac, $mark ) = @_;
    my $logger = get_logger();
    call_ipsetd("/ipset/unmark_mac?local=0",{
        "mac" => $mac
    });
    return (1);
}

=item call_ipsetd

call_ipsetd

=cut

sub call_ipsetd {
    my ($path, $data) = @_;
    my $response;
    eval {
        $response = pf::api::unifiedapiclient->default_client->call("POST", "/api/v1$path", $data);
    };
    if ($@) {
        get_logger()->error("Error updating ipset $path : $@");;
    }
    return $response;
}

=item get_mangle_mark_for_mac

Return 4

=cut

sub get_mangle_mark_for_mac {
    my ( $self, $mac ) = @_;
    return 4;
}

=item update_ipset

Update session when the ip address change

=cut

sub update_node {
    my ( $self, $oldip, $srcip, $srcmac ) = @_;
    my $logger = get_logger();
    my $view_mac = node_view($srcmac);
    my $src_ip = new NetAddr::IP::Lite clean_ip($srcip);
    my $old_ip = new NetAddr::IP::Lite clean_ip($oldip);
    my $id = $view_mac->{'category_id'};
    my $open_security_event_count = pf::security_event::security_event_count_reevaluate_access($srcmac);
    my $mark = $IPTABLES_MARK_UNREG if ($view_mac->{'status'} eq $STATUS_UNREGISTERED) // $IPTABLES_MARK_REG;
    if ($open_security_event_count != 0) {
        $mark = $IPTABLES_MARK_ISOLATION;
    }
    if ($view_mac->{'last_connection_type'} eq $connection_type_to_str{$INLINE}) {
        foreach my $network ( keys %ConfigNetworks ) {
            next if ( !pf::config::is_network_type_inline($network) );

            my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});

            #Delete from ipset session if the ip change
            if ($net_addr->contains($old_ip)) {
                 call_ipsetd("/ipset/unmark_ip?local=0",{
                    "ip" => $oldip
                 });
            }
            #Add in ipset session if the ip change
            if ($net_addr->contains($src_ip)) {
                if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
                    call_ipsetd("/ipset/mark_ip_layer3?local=0",{
                        "network" => $network,
                        "role_id" => "".$id,
                        "ip"      => $srcip
                    });
                } else {
                    call_ipsetd("/ipset/mark_ip_layer2?local=0",{
                        "network" => $network,
                        "role_id" => "".$id,
                        "ip"      => $srcip
                    });
                }
            }

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
                } else {
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
    my $logger = get_logger();
    $logger->info( "flushing iptables" );
    safe_pf_run(qw(/sbin/iptables -t mangle -F));
}

=item ipdates_update_set

Update the set

=cut

sub iptables_update_set {
    my ( $mac, $old, $new ) = @_;

    my $ip = pf::ip4log::mac2ip($mac);

    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $ip = new NetAddr::IP::Lite clean_ip($ip);
        if ($net_addr->contains($ip)) {
            if ($ConfigNetworks{$network}{'type'} =~ /^$NET_TYPE_INLINE_L3$/i) {
                safe_pf_run(qw(sudo ipset del), "PF-iL3_ID$old\_$network", "$ip", '-exist') if defined($old);
                safe_pf_run(qw(sudo ipset add), "PF-iL3_ID$new\_$network", "$ip", '-exist') if defined($old);
            } else {
                safe_pf_run(qw(sudo ipset del), "PF-iL2_ID$old\_$network", "$ip", '-exist') if defined($old);
                safe_pf_run(qw(sudo ipset add), "PF-iL2_ID$new\_$network", "$ip", '-exist') if defined($old);
            }
        }
    }
}

# TODO wrap this into the commit transaction system of IPTables::Interface
# TODO once updated, we should re-validate that the marks are ok and re-try otherwise (maybe in a loop)
sub update_mark {
    my ($self , $mac, $old_mark, $new_mark) = @_;

    $self->iptables_unmark_node($mac, $old_mark);
    $self->iptables_mark_node($mac, $new_mark);
    return 1;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
