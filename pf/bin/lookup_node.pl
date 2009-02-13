#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

# define this function to return whatever data you'd like
# it's called via "pfcmd lookup node <mac>", through the administrative GUI,
# or as the content of a violation action

use pf::util;
use pf::iplog;
use pf::node;
use pf::os;

sub lookup_node {
    my ($mac) = @_;

    my $return = "";

    if ( node_exist($mac) ) {

        my $node_info = node_view($mac);
        $return .= "Address : $mac";

        if ( mac2ip($mac) ) {
            $return .= " (" . mac2ip($mac) . ")\n";
        } else {
            $return .= "\n";
        }

        $owner  = $node_info->{'pid'};
        $status = $node_info->{'status'};
        if ( $status eq "reg" ) {
            $status = "registered";
        } elsif ( $status eq "unreg" ) {
            $status = "unregistered";
        } elsif ( $status eq "grace" ) {
            $status = "grace";
        }
        $owner = "unregistered" if ( $owner eq '1' );
        $return .= "Owner   : $owner\n"  if ($owner);
        $return .= "Status  : $status\n" if ($status);
        $return .= "Name    : " . $node_info->{'computername'} . "\n"
            if ( $node_info->{'computername'} );
        $return .= "Notes   : " . $node_info->{'notes'} . "\n"
            if ( $node_info->{'notes'} );

        my $vendor = oui_to_vendor($mac);
        if ($vendor) {
            $return .= "Vendor  : $vendor\n";
        }

        $return .= "Browser : " . $node_info->{'user_agent'} . "\n"
            if ( $node_info->{'user_agent'} );

        if ( $node_info->{'dhcp_fingerprint'} ) {
            my $fingerprint_info
                = dhcp_fingerprint_view( $node_info->{'dhcp_fingerprint'} );
            my $os = $fingerprint_info->{'description'};
            $return .= "OS      : $os\n" if ( defined($os) );
        }

        my $port   = $node_info->{'port'};
        my $switch = $node_info->{'switch'};
        my $vlan   = $node_info->{'vlan'};
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

    } else {

        $return = "Node $mac is not a known node!\n";

    }
    return ($return);
}

1;
