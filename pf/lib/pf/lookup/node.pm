package pf::lookup::node;

=head1 NAME

pf::lookup::node

=head1 SYNOPSYS

define this function to return whatever data you'd like
it's called via "pfcmd lookup node <mac>", through the administrative GUI,
or as the content of a violation action

=cut


use strict;
use warnings;
use diagnostics;

use pf::config;
use pf::util;
use pf::iplog;
use pf::node;
use pf::os;
use pf::config;
use pf::locationlog;

sub lookup_node {
    my ($mac) = @_;

    my $return = "";

    if ( node_exist($mac) ) {

        my $node_info = node_view($mac);
        $return .= "MAC Address    : $mac\n";

        # fetch IP and DHCP information
        my $node_iplog_info = iplog_view_open_mac($mac);
        if (defined($node_iplog_info->{'ip'})) {

            $return .= "IP Address     : ".$node_iplog_info->{'ip'}." (active)\n";
            $return .= "IP Info        : IP active since " . $node_iplog_info->{'start_time'} .
                       " and DHCP lease valid until ".$node_iplog_info->{'end_time'}."\n";
            
        } else {
            my @node_iplog_history_info = iplog_history_mac($mac);
            if (ref($node_iplog_history_info[0]) eq 'HASH' && defined($node_iplog_history_info[0]->{'ip'})) {
                my $latest_iplog = $node_iplog_history_info[0];
                $return .= "IP Address     : ".$latest_iplog->{'ip'}." (inactive)\n";
                $return .= "IP Info        : IP was last seen active between " . $latest_iplog->{'start_time'} .
                           " and ". $latest_iplog->{'end_time'} . "\n";
            } else {
                $return .= "IP Address     : Unknown\n";
                $return .= "IP Info        : No IP information available\n";
            }
        }

        # DHCP history
        $return .= "DHCP Info      : Last DHCP request at ".$node_info->{'last_dhcp'}."\n";

        my $owner  = $node_info->{'pid'};
        my $category = $node_info->{'category'};
        if (!defined($category) || $category eq '') {
            $category = 'No category';
        }
        my $status = $node_info->{'status'};
        if ( $status eq "reg" ) {
            $status = "registered";
        } elsif ( $status eq "unreg" ) {
            $status = "unregistered";
        } elsif ( $status eq "grace" ) {
            $status = "grace";
        }
        $owner = "unregistered" if ( $owner eq '1' );
        $return .= "Owner          : $owner\n"  if ($owner);
        $return .= "Category       : $category\n" if ($category);
        $return .= "Status         : $status\n" if ($status);
        $return .= "Name           : " . $node_info->{'computername'} . "\n"
            if ( $node_info->{'computername'} );
        $return .= "Notes          : " . $node_info->{'notes'} . "\n"
            if ( $node_info->{'notes'} );

        my $vendor = oui_to_vendor($mac);
        if ($vendor) {
            $return .= "MAC Vendor     : $vendor\n";
        }

        my $voip = $node_info->{'voip'};
        $return .= "VoIP           : $voip\n" if ($voip);

        # TODO: output useragent class like in dhcp fingerprint

        $return .= "Browser        : " . $node_info->{'user_agent'} . "\n"
            if ( $node_info->{'user_agent'} );

        if ( $node_info->{'dhcp_fingerprint'} ) {
            my @fingerprint_info_array
                = dhcp_fingerprint_view( $node_info->{'dhcp_fingerprint'} );
            if ( scalar(@fingerprint_info_array == 1) ) {
                my $fingerprint_info = $fingerprint_info_array[0];
                my $os = $fingerprint_info->{'os'};
                $return .= "OS             : $os\n" if ( defined($os) );
            }
        }

        if (lc($Config{'network'}{'mode'}) eq 'vlan') {
            my @last_locationlog_entry = locationlog_history_mac($mac);
            if ($last_locationlog_entry[0]) {
                my $is_entry_active = 1;
                # if end_time is null or is set to 0
                if (defined($last_locationlog_entry[0]->{'end_time'}) && $last_locationlog_entry[0]->{'end_time'} !~ /0000/) {
                    $is_entry_active = 0;
                }
                $return .= "Location       : port ". $last_locationlog_entry[0]->{'port'}." "
                        .  " (vlan " . $last_locationlog_entry[0]->{'vlan'}.")"
                        .  " on switch ".$last_locationlog_entry[0]->{'switch'}
                        .  "\n";

                if (exists($last_locationlog_entry[0]->{'connection_type'})) {
                    $return .= "Connection type: ".$last_locationlog_entry[0]->{'connection_type'}."\n";
                } else {
                    $return .= "Connection type: UNKNOWN\n";
                }

                if (defined($last_locationlog_entry[0]->{'dot1x_username'})) {
                    $return .= "802.1X Username: ".$last_locationlog_entry[0]->{'dot1x_username'}."\n";
                }

                if (defined($last_locationlog_entry[0]->{'ssid'})) {
                    $return .= "Wireless SSID  : ".$last_locationlog_entry[0]->{'ssid'}."\n";
                }

                if ($is_entry_active) {
                    $return .= "Last activity  : currently active\n";
                } else {
                    $return .= "Last activity  : ".$last_locationlog_entry[0]->{'end_time'}."\n";
                }
            } else {
                $return .= "No connectivity information available (We probably only saw a DHCP request)\n";
            }
        } else {
            my $port   = $node_info->{'last_port'};
            my $switch = $node_info->{'last_switch'};
            my $vlan   = $node_info->{'last_vlan'};
            my $switch_ip;
            my $switch_mac;
            if ($switch) {
                if ( valid_ip($switch) ) {
                    $switch_ip = $switch;
                } elsif ( valid_mac($switch) ) {
                    $switch_mac = $switch;
                    $switch_ip  = mac2ip($switch);
                }
            }
            if ( $port && ( $switch_ip || $switch_mac ) && $vlan ) {
                $return .= "Location: port $port (vlan $vlan) on switch "
                    . ( $switch_ip || $switch_mac );
                if ( $switch_ip && $switch_mac ) {
                    $return .= " ($switch_mac)";
                }
                $return .= "\n";
            }
        }

    } else {

        $return = "Node $mac is not a known node!\n";

    }
    return ($return);
}

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009,2010 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
