#!/usr/bin/perl

=head1 NAME

rlm_perl_packetfence.pl - FreeRadius PacketFence integration module

=head1 DESCRIPTION

rlm_perl_packetfence.pl contains the functions necessary to
integrate PacketFence and FreeRADIUS

=cut
# FIXME this no longer works starting with the feature.rlm-soap branch. 
# It could be made to work, we haven't considered it yet.

use strict;
use warnings;
use diagnostics;
use DBI;
use Sys::Syslog;
use Readonly;

# Configuration parameters
use constant {
    # Database connection settings
    DB_HOSTNAME => 'localhost',
    DB_NAME     => 'pf',
    DB_USER     => 'pf',
    DB_PASS     => 'pf',
    # VLAN configuration
    VLAN_GUEST        => 5,
    VLAN_REGISTRATION => 2,
    VLAN_ISOLATION    => 3,
    VLAN_NORMAL       => 1,
    VLAN_DENIED       => -1,  # When working with some particular APs (Cisco AP's for example), there is a restriction
    # regarding VLANs and SSIDs: the same VLAN can NOT be present on two different SSIDs. For example, if the isolation
    # VLAN is not available in a SSID and we try to put a device in that VLAN, the device will be in a connect loop. 
    # In this case rather than creating two Isolation VLANs, we return -1 as the VLAN. This actually sends back an 
    # 'Access-Reject' to the AP and the client stops trying to reconnect.
    #
    # Category configuration, by default we dont't use categories
    #CATEGORY_GUEST    => 'Guest',
    #CATEGORY_NORMAL   => 'Staff',
    # SSID configuration
    SSID_OPEN         => 'Open_SSID',
    SSID_SECURE       => 'Secure_SSID'
};

require 5.8.8;

# This is very important! Without this script will not get the filled hashes from main.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);
#use Data::Dumper;

#
# This the remapping of return values
#
use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
use constant    RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
use constant    RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
use constant    RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
use constant    RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
use constant    RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
use constant    RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
use constant    RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
use constant    RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
use constant    RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

Readonly::Scalar our $NO_VIOLATION => 'No Violation';

# Function to handle authorize
sub authorize {
    # For debugging purposes only
    #&log_request_attributes;

    # returning Reject to force people to upgrade from our old authorize hook into our new post_auth hook
    # otherwise they could upgrade and allow everyone in without being aware of it
    openlog("rlm_perl_packetfence", "perror,pid","user");
    my $ERROR_MSG =
        "*** WARNING ***: PacketFence (rlm_perl_packetfence.pl) should no longer run from authorize section."
        ." Update your FreeRADIUS configuration to call perl module from post-auth section instead!"
    ;
    &radiusd::radlog(1, $ERROR_MSG);
    syslog("info", $ERROR_MSG);
    closelog();

    return RLM_MODULE_REJECT;
}

# Function to handle post_auth
sub post_auth {
    # For debugging purposes only
    #&log_request_attributes;

    my $mac = $RAD_REQUEST{'Calling-Station-Id'};
    # freeradius 2 provides the switch_ip in NAS-IP-Address not Client-IP-Address 
    # Client-IP-Address is a non-standard freeradius1 attribute
    my $switch_ip = $RAD_REQUEST{'NAS-IP-Address'} || $RAD_REQUEST{'Client-IP-Address'};
    my $user_name = $RAD_REQUEST{'User-Name'};
    my $is_eap_request = 0;
    if (exists($RAD_REQUEST{'EAP-Type'})) {
        $is_eap_request = 1;
    }

    my $ssid = find_ssid();
    if (!defined($ssid)) {
        # We were not able to parse SSID. For now, I don't think it's important enough to even log
        # syslog("info", "Unable to parse SSID from request.");
        if ($is_eap_request) {
            $ssid = SSID_SECURE;
        } else {
            $ssid = SSID_OPEN;
        }
    }

    #format MAC
    $mac =~ s/ /0/g;
    $mac =~ s/-/:/g;
    $mac =~ s/\.//g;
    if (length($mac) == 12) {
        $mac = substr($mac,0,2) . ":" . substr($mac,2,2) . ":" . substr($mac,4,2) . ":" . 
               substr($mac,6,2) . ":" . substr($mac,8,2) . ":" . substr($mac,10,2);
    }
    $mac = lc($mac);

    &radiusd::radlog(1, "PacketFence SWITCH: $switch_ip");
    &radiusd::radlog(1, "PacketFence MAC: $mac");
    &radiusd::radlog(1, "PacketFence USER: $user_name");

    if (length($mac) == 17) {
        my $result = getVlan($switch_ip, $mac, $is_eap_request, $ssid);
        if (!defined($result) || $result =~ /^$/) {
            &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
        } elsif ($result > 0) {
            &radiusd::radlog(1, "PacketFence RESULT VLAN: $result");
            $RAD_REPLY{'Tunnel-Medium-Type'} = 6;
            $RAD_REPLY{'Tunnel-Type'} = 13;
            $RAD_REPLY{'Tunnel-Private-Group-ID'} = $result;
        } else {
            &radiusd::radlog(1, "PacketFence RESULT VLAN: $result");
            &radiusd::radlog(1, "PacketFence DENIED CONNECTION");
            return RLM_MODULE_REJECT;
        }
    }


    return RLM_MODULE_OK;
}

# Here is the decision process:
#
# non-secure, violation                          => VLAN per violation
# non-secure, no violation, not-registered       => registration VLAN
# non-secure, no violation, registered           => guest VLAN
# secure, violation                              => VLAN per violation
# secure, no violation, not-registered           => auto-registration, normal VLAN
# secure, no violation, registered               => normal VLAN
#
sub getVlan {

    my ($switch_ip, $mac, $is_eap_request, $ssid) = @_;
    $mac = lc($mac);
    
    openlog("rlm_perl_packetfence", "perror,pid","user");
    syslog("info", "getVlan called with switch_ip $switch_ip, SSID $ssid, mac $mac, is_eap_request $is_eap_request");

    # create database connection
    my $mysql_connection = DBI->connect("dbi:mysql:dbname=".DB_NAME.";host=".DB_HOSTNAME, 
                                        DB_USER, DB_PASS, {PrintError => 0});

    if (!defined($mysql_connection)) {
      syslog("info", "Can't connect to the database.");
      closelog();
      return;
    }

    # read node info (status, category, violations)
    #
    # Here are the possible results/scenarios:
    #+-------------------+-----+----------+--------+---------------+
    #| mac               | pid | category | status | isolationVlan |
    #+-------------------+-----+----------+--------+---------------+
    #| d8:d3:85:07:15:78 | 1   | ''       | unreg  | No Violation  | 
    #| 00:12:cf:39:2d:89 | 1   | ''       | unreg  | isolationVlan |
    #+-------------------+-----+----------+--------+---------------+
    #| d8:d3:85:07:15:78 | 1   | ''       | reg    | No Violation  | 
    #| 00:12:cf:39:2d:89 | 1   | ''       | reg    | isolationVlan |
    #+-------------------+-----+----------+--------+---------------+
    #| d8:d3:85:07:15:78 | 1   | Guest    | reg    | No Violation  | 
    #| 00:12:cf:39:2d:89 | 1   | Guest    | reg    | isolationVlan |
    #+-------------------+-----+----------+--------+---------------+

    my $node_info = $mysql_connection->selectrow_hashref("
        SELECT node.mac, node.pid, IFNULL(node_category.name,'') AS category, node.status, 
            IFNULL(class.vlan,'$NO_VIOLATION') AS isolationVlan 
        FROM node 
            LEFT JOIN node_category USING (category_id) 
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status='open' 
            LEFT JOIN class ON violation.vid=class.vid 
        WHERE node.mac='$mac'
        ORDER BY class.priority DESC LIMIT 1");

    # check if mac exists already in database
    # if not, create the node
    if ( !defined($node_info) ) {
        syslog("info", "SSID $ssid: $mac does not yet exist in database -> will be created now");
        $mysql_connection->do("
            INSERT INTO node(mac,detect_date,status,last_arp) 
            VALUES('$mac',now(),'unreg',now())");
    } elsif (ref($node_info) ne 'HASH') {
      syslog("info", "SSID $ssid: Error while reading info for $mac; VLAN could not be determined");
      closelog();
      $mysql_connection->disconnect();
      return;
    }

    # assume User is not wanted unless proven otherwise
    my $correctVlan = VLAN_DENIED;

    # if connecting to the non-scure SSID, only registered devices can get access.
    if ($ssid eq SSID_OPEN) {

        # check if node has open violation(s). if so, returning violation VLAN
        if ($node_info->{'isolationVlan'} eq $NO_VIOLATION) {

            # if not registered
            if ($node_info->{'status'} eq 'unreg') {
                $correctVlan = VLAN_REGISTRATION; 
                syslog("info", "SSID $ssid: $mac is unregistered. Returning Vlan $correctVlan");
            } else {
                # by default we don't use categories but if we were to, below is the code that could be used:
                #
                # if ($node_info->{'category'} eq CATEGORY_GUEST) {
                #     $correctVlan = VLAN_GUEST; 
                # elsif ($node_info->{'category'} eq CATEGORY_AAAA) {
                #     $correctVlan = VLAN_AAAA; 
                # elsif ($node_info->{'category'} eq CATEGORY_BBBB) {
                #     $correctVlan = VLAN_BBBB; 
                # else {
                #     $correctVlan = VLAN_DENIED;
                # } 
                $correctVlan = VLAN_GUEST; 
                syslog("info", "SSID $ssid: $mac is registered. Returning Vlan $correctVlan");
            }

        } else {
            $correctVlan = getViolationVLAN($node_info->{'isolationVlan'});
            syslog("info", "SSID $ssid: $mac has open violation(s). Kicking out");
        }
    }

    # if connecting to the Secure SSID, only devices registered as Normal with no violation can get access.
    # we deny access to any other device!
    if ($ssid eq SSID_SECURE) {

        # check if node has open violation(s). if so, returning violation VLAN
        if ($node_info->{'isolationVlan'} eq $NO_VIOLATION) {
            
            # Here we think that since Radius already verified the users credentials when it gets here, 
            # we automatically register their devices.
            if ($node_info->{'status'} eq 'unreg') {
                syslog("info", "SSID $ssid: $mac is not registered but user is authenticated -> registering mac");
                $mysql_connection->do("
                    UPDATE node 
                    SET regdate=now(), status='reg'
                    WHERE mac='$mac'");
            }
            # by default we don't use categories but if we were to, see code in the SSID_OPEN section
            $correctVlan = VLAN_NORMAL;
            syslog("info", "SSID $ssid: $mac is registered. Returning Vlan $correctVlan");
        } else {
            $correctVlan = getViolationVLAN($node_info->{'isolationVlan'});
            syslog("info", "SSID $ssid: $mac has open violation(s). Returning Vlan $correctVlan");
        }
    }

    # update locationlog if necessary:
    # in order to avoid unnecessary WIFI entries in locationlog (since authentication->reauthentication 
    # occurs very often), we don't add a new entry if there is already one.
    #
    # In some setups we don't use VLAN IDs but VLAN Names. Since the vlan field in the locationlog table 
    # is varchar(4), we need to truncate the VLAN name and take only the first 4 characters.
    #my $locationlogExists = $mysql_connection->selectrow_array("
    #    SELECT count(*) 
    #    FROM locationlog 
    #    WHERE mac='$mac' AND switch='$switch_ip' AND port='WIFI' AND vlan='" . substr($correctVlan, 0, 4) . "' 
    #        AND (end_time = 0 OR isnull(end_time))");
    my $locationlogExists = $mysql_connection->selectrow_array("
        SELECT count(*) 
        FROM locationlog 
        WHERE mac='$mac' AND switch='$switch_ip' AND port='WIFI' and vlan='$correctVlan' 
            AND (end_time = 0 OR isnull(end_time))");
    if ($locationlogExists == 0) {
        $mysql_connection->do("
            UPDATE locationlog 
            SET end_time=now() 
            WHERE mac='$mac' AND (end_time = 0 OR isnull(end_time))");
        $mysql_connection->do("
            INSERT INTO locationlog(mac,switch,port,vlan,start_time) 
            VALUES('$mac','$switch_ip','WIFI',$correctVlan,now())");
        #$mysql_connection->do("
        #    INSERT INTO locationlog(mac,switch,port,vlan,start_time) 
        #    VALUES('$mac','$switch_ip','WIFI','" . substr($correctVlan, 0, 4) . "',now())");
    }
    # By default we only store the AP's IP in the node record. We could store more info like the SSID name and the Vlan
    #$mysql_connection->do("
    #    UPDATE node SET switch='$switch_ip', port='WIFI', notes='$ssid', vlan='$correctVlan' 
    #    WHERE mac='$mac'");
    $mysql_connection->do("
        UPDATE node 
        SET switch='$switch_ip', port='WIFI' 
        WHERE mac='$mac'");
   
   
    # return the correct VLAN, close resources
    closelog();
    $mysql_connection->disconnect();
    return $correctVlan;
}

sub getViolationVLAN {
  my ($isolationVlan) = @_;
  syslog("info","this violation says that it should go in vlan $isolationVlan");
  if ($isolationVlan eq 'registrationVlan') {
    return VLAN_REGISTRATION;
  } elsif ($isolationVlan eq 'normalVlan') {
    return VLAN_NORMAL;
  } else {
    # I could test only for isolation but there is no other value left so lets catch it all
    return VLAN_ISOLATION;
  }

  # TODO: Sending VLAN_DENIED (-1) instead of the correct violation VLAN breaks Nessus Scans on registration
  # but its a lot friendlier with network ressources because clients like the iPhone won't retry
  # connnections over and over if they get a -1 but if they get a VLAN unavailable they will retry
  #return VLAN_DENIED
}

sub find_ssid {

    if (defined($RAD_REQUEST{'Cisco-AVPair'})) {
        if ($RAD_REQUEST{'Cisco-AVPair'} =~ /^ssid=(.*)$/) { # ex: Cisco-AVPair = "ssid=Inverse-Secure"
            return $1;
        } else {
            syslog("info", "Unable to parse SSID out of Cisco-AVPair: ".$RAD_REQUEST{'Cisco-AVPair'});
            return;
        }

    } elsif (defined($RAD_REQUEST{'Aruba-Essid-Name'})) {
        return $RAD_REQUEST{'Aruba-Essid-Name'};

    } elsif (defined($RAD_REQUEST{'Colubris-AVPair'})) {
        # With HP Procurve AP Ccontroller, we receive an array of settings in Colubris-AVPair:
        # Colubris-AVPair = ssid=Inv_Controller
        # Colubris-AVPair = group=Default Group
        # Colubris-AVPair = phytype=IEEE802dot11g
        foreach (@{$RAD_REQUEST{'Colubris-AVPair'}}) {
            if (/^ssid=(.*)$/) { return $1; }
        }
        syslog("info", "Unable to parse SSID out of Colubris-AVPair: ".@{$RAD_REQUEST{'Colubris-AVPair'}});
        return;

    } else {
        return;
    }
}

# Function to handle authenticate
sub authenticate {

}

# Function to handle preacct
sub preacct {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle accounting
sub accounting {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle checksimul
sub checksimul {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle pre_proxy
sub pre_proxy {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle post_proxy
sub post_proxy {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle xlat
sub xlat {
        # For debugging purposes only
#       &log_request_attributes;

}

# Function to handle detach
sub detach {
        # For debugging purposes only
#       &log_request_attributes;

        # Do some logging.
        &radiusd::radlog(0,"rlm_perl::Detaching. Reloading. Done.");
}

#
# Some functions that can be called from other functions
#

sub log_request_attributes {
        # This shouldn't be done in production environments!
        # This is only meant for debugging!
        for (keys %RAD_REQUEST) {
                &radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
        }
}

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2002  The FreeRADIUS server project

Copyright (C) 2002  Boian Jordanov <bjordanov@orbitel.bg>

Copyright (C) 2006-2010  Inverse inc. <support@inverse.ca>

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
