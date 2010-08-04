#!/usr/bin/perl

=head1 NAME

rlm_perl_packetfence.pl - FreeRadius PacketFence integration module

=head1 DESCRIPTION

rlm_perl_packetfence.pl contains the functions necessary to
integrate PacketFence and FreeRADIUS

=cut

use strict;
use warnings;
use diagnostics;
use DBI;
use Sys::Syslog;

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
    VLAN_NORMAL       => 1
};

require 5.8.8;

# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
#use Data::Dumper;

# This is hash wich hold original request from radius
#my %RAD_REQUEST;
# In this hash you add values that will be returned to NAS.
#my %RAD_REPLY;
#This is for check items
#my %RAD_CHECK;

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

# Function to handle authorize
sub authorize {
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


        #format MAC
        $mac =~ s/ /0/g;
        $mac =~ s/-/:/g;
        $mac =~ s/\.//g;
        if (length($mac) == 12) {
            $mac = substr($mac,0,2) . ":" . substr($mac,2,2) . ":" . substr($mac,4,2) . ":" . substr($mac,6,2) . ":" . substr($mac,8,2) . ":" . substr($mac,10,2);
        }
        $mac = lc($mac);

        &radiusd::radlog(1, "PacketFence SWITCH: $switch_ip");
        &radiusd::radlog(1, "PacketFence MAC: $mac");
        &radiusd::radlog(1, "PacketFence USER: $user_name");

        if (length($mac) == 17) {
            my $result = getVlan($switch_ip, $mac, $is_eap_request);
            if (!defined($result) || $result =~ /^$/) {
                &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
            } elsif ($result > 0) {
                &radiusd::radlog(1, "PacketFence RESULT VLAN: $result");
                if ($result > 0) {
                    $RAD_REPLY{'Tunnel-Medium-Type'} = 6;
                    $RAD_REPLY{'Tunnel-Type'} = 13;
                    $RAD_REPLY{'Tunnel-Private-Group-ID'} = $result;
                }
            } else {
                &radiusd::radlog(1, "PacketFence RESULT VLAN: $result");
                &radiusd::radlog(1, "PacketFence DENIED CONNECTION");
                return RLM_MODULE_REJECT;
            }
        }


        return RLM_MODULE_OK;
}

# Function to handle authenticate
sub authenticate {
        # For debugging purposes only
#       &log_request_attributes;

        if ($RAD_REQUEST{'User-Name'} =~ /^baduser/i) {
                # Reject user and tell him why
                $RAD_REPLY{'Reply-Message'} = "Denied access by rlm_perl function";
                return RLM_MODULE_REJECT;
        } else {
                # Accept user and set some attribute
                $RAD_REPLY{'h323-credit-amount'} = "100";
                return RLM_MODULE_OK;
        }
}

# Function to handle preacct
sub preacct {
        # For debugging purposes only
#       &log_request_attributes;

        return RLM_MODULE_OK;
}

# Function to handle accounting
sub accounting {
        # For debugging purposes only
#       &log_request_attributes;

        # You can call another subroutine from here
        &test_call;

        return RLM_MODULE_OK;
}

# Function to handle checksimul
sub checksimul {
        # For debugging purposes only
#       &log_request_attributes;

        return RLM_MODULE_OK;
}

# Function to handle pre_proxy
sub pre_proxy {
        # For debugging purposes only
#       &log_request_attributes;

        return RLM_MODULE_OK;
}

# Function to handle post_proxy
sub post_proxy {
        # For debugging purposes only
#       &log_request_attributes;

        return RLM_MODULE_OK;
}

# Function to handle post_auth
sub post_auth {
        # For debugging purposes only
        #&log_request_attributes;


        return RLM_MODULE_OK;
}

# Function to handle xlat
sub xlat {
        # For debugging purposes only
#       &log_request_attributes;

        # Loads some external perl and evaluate it
        my ($filename,$a,$b,$c,$d) = @_;
        &radiusd::radlog(1, "From xlat $filename ");
        &radiusd::radlog(1,"From xlat $a $b $c $d ");
        local *FH;
        open FH, '<', $filename or die "open '$filename' $!";
        local($/) = undef;
        my $sub = <FH>;
        close FH;
        my $eval = qq{ sub handler{ $sub;} };
        eval $eval;
        eval {main->handler;};
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

sub test_call {
        # Some code goes here
}

sub log_request_attributes {
        # This shouldn't be done in production environments!
        # This is only meant for debugging!
        for (keys %RAD_REQUEST) {
                &radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
        }
}

# Here is the decision process:
# 
# registered, guest, secure                      => disconnect (-1)
# registered, guest, non-secure, violation       => disconnect (-1)*
# registered, guest, non-secure, no violation    => guest VLAN
# registered, normal user, secure, violation     => VLAN per violation
# registered, normal user, secure, no violation  => normal VLAN
# registered, normal user, non-secure            => disconnect (-1)
# not-registered, secure                         => disconnect (-1)
# not-registered, non-secure, violation          => disconnect (-1)*
# not-registered, non-secure, no violation       => registration VLAN
#
# *: We disconnect here because if the violation VLAN is a VLAN that is unavailable on the
#    non-secure SSID, the device will be in a connect loop. But if we return -1 the device 
#    stop trying to connect.
#    This breaks Nessus Scans on registration (since they generate a special violation) you
#    might want to change this behaviour in that case.
#    Keep in mind that the underlying problem is that you can't have a the same VLAN Id on
#    both the secure and non-secure SSID.
#
# Here, we included all the code that was pfcmd_ap.pl to avoid costly forks for each request
# TODO: raw SQL is evil, we should port this over to a more suited application-level API
sub getVlan {

    my ($switch_ip, $mac, $is_eap_request) = @_;
    $mac = lc($mac);
    
    openlog("rlm_perl_packetfence", "perror,pid","user");
    syslog("info", "getVlan called with switch_ip $switch_ip, mac $mac, is_eap_request $is_eap_request");
    
    # create database connection
    my $mysql_connection = DBI->connect("dbi:mysql:dbname=".DB_NAME.";host=".DB_HOSTNAME, 
                                        DB_USER, DB_PASS, {PrintError => 0});

    if (!defined($mysql_connection)) { 
      syslog("info", "Can't connect to the database.");
      return undef;
    }

    # check if mac exists already in database
    # if not, create the node
    my $nodeExists = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac'");
    if ($nodeExists == 0) {
      syslog("info", "node $mac does not yet exist in database -> will be created now");
      $mysql_connection->do("INSERT INTO node(mac,detect_date,status,last_arp) VALUES('$mac',now(),'unreg',now())");
    }
    
    # assume User is not wanted unless proven otherwise
    my $correctVlan = -1;
    
    # check if registered
    my $registrationExists = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac' AND status='reg'");
    if ($registrationExists != 0) {

      # --- REGISTERED ---

      # check if 'guest'
      my $isGuest = $mysql_connection->selectrow_array("SELECT count(*) FROM node WHERE mac='$mac' AND pid='guest'");
      if ($isGuest == 1) {

        # --- GUEST ---

        # is the guest on the secure SSID?
        if ($is_eap_request == 1) {

          # a guest on the secure SSID is not normal, return -1
          syslog("info", "node $mac is a guest on secure SSID. Kicking out");
          $correctVlan = -1;

        } else {

          # a guest on the non-secure SSID, does he has any open violation?
          my $nbOpenViolations = $mysql_connection->selectrow_array(
                                                "SELECT count(*) FROM violation WHERE mac='$mac' and status='open'");
          if ($nbOpenViolations > 0) {

            # guest with a violation: send to VLAN configured in violation
            syslog("info", "node $mac is a guest on non-secure SSID with a violation. Kicking out");
            $correctVlan = -1;
                                                
            # TODO: Sending -1 instead of the correct violation VLAN breaks Nessus Scans on registration
            # but its a lot friendlier with network ressources because clients like the iPhone won't retry
            # connnections over and over if they get a -1 but if they get a VLAN unavailable they will retry
            # $correctVlan = getViolationVLAN($mac, $mysql_connection);

          } else {

            # user is registered as a guest on a non-secure SSID and doesn't have violation: put in guest VLAN
            $correctVlan = VLAN_GUEST;

          }       
        }

      } else {

        # --- NOT A GUEST ---

        # is the registered user on secure SSID?
        if ($is_eap_request == 1) {

          # a registered user in the secure SSID, does he has any open violations?
          my $nbOpenViolations = $mysql_connection->selectrow_array(
                                                "SELECT count(*) FROM violation WHERE mac='$mac' and status='open'");
          if ($nbOpenViolations > 0) {

            # registered user with a violation: send to VLAN configured in violation
            $correctVlan = getViolationVLAN($mac, $mysql_connection);
            syslog("info", "node $mac is a registered user with a violation. Violation VLAN: $correctVlan");

          } else {

            # a registered user in the secure SSID without any violations: send in normal VLAN
            $correctVlan = VLAN_NORMAL;

          }
        } else {

          # a registered user on the non-secure SSID is not allowed!
          syslog("info","node $mac is a registered user trying to access non-secure SSID. Kicking out");
          $correctVlan = -1;

        }
      }

    } else {

      # --- NOT REGISTERED ---
      
      # is the unregistered user on secure SSID?
      if ($is_eap_request == 1) {

        # unregistered user shouldn't be on secure SSID, kicking out
        syslog("info","node $mac is an unregistered user on secure SSID. Kicking out");
        $correctVlan = -1;

      } else {

        # does the user has any open violation?
        my $nbOpenViolations = $mysql_connection->selectrow_array(
                                                "SELECT count(*) FROM violation WHERE mac='$mac' and status='open'");
        if ($nbOpenViolations > 0) {

          # --- OPEN VIOLATIONS ---
          # unregistered user on non-secure SSID with violation, disconnect
          syslog("info", "node $mac is an unregistered user with a violation. Kicking out");
          $correctVlan = -1;

          # TODO: Sending -1 instead of the correct violation VLAN breaks Nessus Scans on registration
          # but its a lot friendlier with network ressources because clients like the iPhone won't retry
          # connnections over and over if they get a -1 but if they get a VLAN unavailable they will retry
          # $correctVlan = getViolationVLAN($mac, $mysql_connection);

        } else {

          # unregistered user on non-secure SSID with no open violation, present captive portal
          $correctVlan = VLAN_REGISTRATION;

        }
      }
    }

    # update locationlog if necessary:
    # in order to avoid unnecessary WIFI entries in locationlog (since authentication->reauthentication 
    # occurs very often), we don't add a new entry if there is already one.
    #
    # In some setups we don't use VLAN IDs but VLAN Names. Since the vlan field in the locationlog table 
    # is varchar(4), we need to truncate the VLAN name and take only the first 4 characters.
    #my $locationlogExists = $mysql_connection->selectrow_array("SELECT count(*) FROM locationlog WHERE mac='$mac' AND switch='$switch_ip' AND port='WIFI' and vlan='" . substr($correctVlan, 0, 4) . "' AND (end_time = 0 OR isnull(end_time))");
    my $locationlogExists = $mysql_connection->selectrow_array("SELECT count(*) FROM locationlog WHERE mac='$mac' AND switch='$switch_ip' AND port='WIFI' and vlan='$correctVlan' AND (end_time = 0 OR isnull(end_time))");
    if ($locationlogExists == 0) {
        $mysql_connection->do("UPDATE locationlog SET end_time=now() WHERE mac='$mac' and (end_time = 0 OR isnull(end_time))");
        $mysql_connection->do("INSERT INTO locationlog(mac,switch,port,vlan,start_time) VALUES('$mac','$switch_ip','WIFI',$correctVlan,now())");
        #$mysql_connection->do("INSERT INTO locationlog(mac,switch,port,vlan,start_time) VALUES('$mac','$switch_ip','WIFI','" . substr($correctVlan, 0, 4) . "',now())");
    }
    $mysql_connection->do("UPDATE node SET switch='$switch_ip', port='WIFI' WHERE mac='$mac'");
    
    
    
    # return the correct VLAN, close resources
    syslog("info", "returning VLAN $correctVlan for $mac");
    closelog();
    $mysql_connection->disconnect();
    return $correctVlan;
}

sub getViolationVLAN {
  my ($mac, $mysql_connection) = @_;
  my $vlanToGoTo = $mysql_connection->selectrow_array(
                   "SELECT c.vlan FROM violation v, class c WHERE v.vid=c.vid AND mac='$mac' AND status='open' ".
                   "ORDER BY priority desc LIMIT 1");
  syslog("info","this violation says that it should go in vlan $vlanToGoTo");
  if ($vlanToGoTo eq 'registrationVlan') {
    return VLAN_REGISTRATION;
  } elsif ($vlanToGoTo eq 'normalVlan') {
    return VLAN_NORMAL;
  } else {
    # I could test only for isolation but there is no other value left so lets catch it all
    return VLAN_ISOLATION;
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

Copyright (C) 2006-2009  Inverse inc. <support@inverse.ca>

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
