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

use Time::localtime;

use pf::accounting qw(
    node_accounting_view 
    node_accounting_daily_bw node_accounting_weekly_bw node_accounting_monthly_bw node_accounting_yearly_bw
    node_accounting_daily_time node_accounting_weekly_time node_accounting_monthly_time node_accounting_yearly_time
);
use pf::config;
use pf::iplog;
use pf::locationlog;
use pf::node;
use pf::os;
use pf::useragent qw(node_useragent_view);
use pf::util;

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
            $return .= "IP Info        : IP active since " . $node_iplog_info->{'start_time'};
            if ($node_iplog_info->{'end_time'} ne '0000-00-00 00:00:00') {
                $return .= " and DHCP lease valid until ".$node_iplog_info->{'end_time'};
            }
            $return .= "\n";
            
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

        $return .= "\nNODE USER-AGENT INFORMATION\n";
        $return .= "Raw User-Agent : " . $node_info->{'user_agent'} . "\n" if ( $node_info->{'user_agent'} );
        my $node_useragent = node_useragent_view($mac);
        if (defined($node_useragent->{'mac'})) {
            $return .= "Browser        : " . $node_useragent->{'browser'} . "\n" if ( $node_useragent->{'browser'} );
            $return .= "OS             : " . $node_useragent->{'os'} . "\n" if ( $node_useragent->{'os'} );
            $return .= "Is a device?   : " . $node_useragent->{'device'} . "\n" if ( $node_useragent->{'device'} );
            $return .= "Device name    : " . $node_useragent->{'device_name'} . "\n" 
                if ( $node_useragent->{'device_name'} );
            $return .= "Is a mobile?   : " . $node_useragent->{'mobile'} . "\n" if ( $node_useragent->{'mobile'} );
        }

        $return .= "\nNODE DHCP INFORMATION\n";
        if ( $node_info->{'dhcp_fingerprint'} ) {
            my @fingerprint_info_array
                = dhcp_fingerprint_view( $node_info->{'dhcp_fingerprint'} );
            if ( scalar(@fingerprint_info_array == 1) ) {
                my $fingerprint_info = $fingerprint_info_array[0];
                my $os = $fingerprint_info->{'os'};
                $return .= "OS             : $os\n" if ( defined($os) );
            }
        }
        $return .= "DHCP Info      : Last DHCP request at ".$node_info->{'last_dhcp'}."\n";

        my @last_locationlog_entry = locationlog_history_mac($mac);
        if ($last_locationlog_entry[0] && defined($last_locationlog_entry[0]->{'mac'})) {

            # assignments using ternary operator: if exist assign otherwise unknown
            my $port = defined($last_locationlog_entry[0]->{'port'}) ? 
                $last_locationlog_entry[0]->{'port'} : "UNKNOWN";
            my $vlan = defined($last_locationlog_entry[0]->{'vlan'}) ? 
                $last_locationlog_entry[0]->{'vlan'} : "UNKNOWN";
            my $switch = defined($last_locationlog_entry[0]->{'switch'}) ? 
                $last_locationlog_entry[0]->{'switch'} : "UNKNOWN";
            $return .= "Location       : port $port (vlan $vlan) on switch $switch\n";

            my $con_type = defined($last_locationlog_entry[0]->{'connection_type'}) ?
                $last_locationlog_entry[0]->{'connection_type'} : "UNKNOWN";
            $return .= "Connection type: $con_type\n";

            if (defined($last_locationlog_entry[0]->{'dot1x_username'})) {
                $return .= "802.1X Username: ".$last_locationlog_entry[0]->{'dot1x_username'}."\n";
            }

            if (defined($last_locationlog_entry[0]->{'ssid'})) {
                $return .= "Wireless SSID  : ".$last_locationlog_entry[0]->{'ssid'}."\n";
            }

            # if end_time is null or is set to 0
            if (!defined($last_locationlog_entry[0]->{'end_time'})) {
                $return .= "Last activity  : UNKNOWN\n";
            } elsif (defined($last_locationlog_entry[0]->{'end_time'}) 
                && $last_locationlog_entry[0]->{'end_time'} !~ /0000/) {
                $return .= "Last activity  : currently active\n";
            } else {
                $return .= "Last activity  : ".$last_locationlog_entry[0]->{'end_time'}."\n";
            }
        } else {
            $return .= "No connectivity information available (We probably only saw a DHCP request)\n";
        }

    } else {

        $return = "Node $mac is not a known node!\n";

    }
    
    my $node_accounting = node_accounting_view($mac);
    if (defined($node_accounting->{'mac'})) {
            $return .= "\nACCOUNTING INFORMATION AND STATISTICS\n";
            $return .= "Last Session   :\n"; 
            $return .= "    Session Start   : " . $node_accounting->{'acctstarttime'} . "\n" if ( $node_accounting->{'acctstarttime'} );
            $return .= "    Session End     : " . $node_accounting->{'acctstoptime'} . "\n" if ( $node_accounting->{'acctstoptime'} && $node_accounting->{'status'} eq 'not connected' );
            $return .= "    Session Time    : " . $node_accounting->{'acctsessiontime'} . " Minutes\n" if ( $node_accounting->{'acctsessiontime'} && $node_accounting->{'status'} eq 'not connected' );
            $return .= "    Terminate Cause : " . $node_accounting->{'acctterminatecause'} . "\n" if ( $node_accounting->{'acctterminatecause'} && $node_accounting->{'status'} eq 'not connected' );
            $return .= "    Bandwitdh Used  : " . pretty_bandwidth($node_accounting->{'accttotal'}) if ( $node_accounting->{'accttotal'} );
            $return .= "\n";
            $return .= "Bandwidth Statistics :\n";
            my $daily_bw = node_accounting_daily_bw($mac);
            $return .= "    Today           : ";
            if ($daily_bw->{'accttotal'}) { $return .= pretty_bandwidth($daily_bw->{'accttotal'}) . " (IN: " . pretty_bandwidth($daily_bw->{'acctoutput'}) ." // OUT: " . pretty_bandwidth($daily_bw->{'acctinput'}) . " ) \n" } else { $return .= "0.0 MB \n" ; }

            my $weekly_bw = node_accounting_weekly_bw($mac);
            $return .= "    This Week       : ";
            if ($weekly_bw->{'accttotal'}) { $return .= pretty_bandwidth($weekly_bw->{'accttotal'}) . " (IN: " . pretty_bandwidth($weekly_bw->{'acctoutput'})  . " // OUT: " . pretty_bandwidth($weekly_bw->{'acctinput'}) . " ) \n" } else { $return .= "0.0 MB \n"; }

            my $monthly_bw = node_accounting_monthly_bw($mac);
            $return .= "    This Month      : ";
            if ($monthly_bw->{'accttotal'}) { $return .= pretty_bandwidth($monthly_bw->{'accttotal'}) . " (IN: " . pretty_bandwidth($monthly_bw->{'acctoutput'})  . " // OUT: " . pretty_bandwidth($monthly_bw->{'acctinput'}) . " ) \n" } else { $return .= "0.0 MB\n"; } 

            my $yearly_bw = node_accounting_yearly_bw($mac);
            $return .= "    This Year       : ";
            if ($yearly_bw->{'accttotal'}) { $return .= pretty_bandwidth($yearly_bw->{'accttotal'}) . " (IN: " . pretty_bandwidth($yearly_bw->{'acctoutput'})  . " // OUT: " . pretty_bandwidth($yearly_bw->{'acctinput'}) . " ) \n"} else { $return .= "0.0 MB\n"; }
            
            $return .= "\n";

            $return .= "Time Connected       :\n";
            my $daily_time = node_accounting_daily_time($mac);
            $return .= "    Today           : ";
            if ( $daily_time->{'accttotaltime'} ) { $return .= $daily_time->{'accttotaltime'} . " Minutes \n" } else { $return .= "0.0 Minutes \n" ;}
            my $weekly_time = node_accounting_weekly_time($mac);
            $return .= "    This Week       : ";
            if ( $weekly_time->{'accttotaltime'} ) { $return .= $weekly_time->{'accttotaltime'}  . " Minutes \n" } else { $return .= "0.0 Minutes \n" ;}
            my $monthly_time = node_accounting_monthly_time($mac);
            $return .= "    This Month      : ";
            if ( $monthly_time->{'accttotaltime'} ) { $return .= $monthly_time->{'accttotaltime'}  . " Minutes \n" } else { $return .= "0.0 Minutes \n" ;}
            my $yearly_time = node_accounting_yearly_time($mac);
            $return .= "    This Year       : ";
            if ( $yearly_time->{'accttotaltime'} ){ $return .= $yearly_time->{'accttotaltime'}  . " Minutes \n"} else { $return .= "0.0 Minutes \n" ;}
        }

    return ($return);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
