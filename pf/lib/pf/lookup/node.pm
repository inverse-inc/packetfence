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

        my $owner  = $node_info->{'pid'};
        my $status = $node_info->{'status'};
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

        # TODO: output useragent class like in dhcp fingerprint

        $return .= "Browser : " . $node_info->{'user_agent'} . "\n"
            if ( $node_info->{'user_agent'} );

        if ( $node_info->{'dhcp_fingerprint'} ) {
            my @fingerprint_info_array
                = dhcp_fingerprint_view( $node_info->{'dhcp_fingerprint'} );
            if ( scalar(@fingerprint_info_array == 1) ) {
                my $fingerprint_info = $fingerprint_info_array[0];
                my $os = $fingerprint_info->{'os'};
                $return .= "OS      : $os\n" if ( defined($os) );
            }
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

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009 Inverse inc.

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
