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
    # PacketFence SOAP Server settings
    ADMIN_USER     => 'admin',
    ADMIN_PASS     => 'qwerty',
    WEBADMIN_HOST  => 'localhost:1443',
    API_URI        => 'https://www.packetfence.org/PFAPI' #don't change this unless you know what you are doing
};

require 5.8.8;

# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);

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

use SOAP::Lite
    # SOAP global error handler (mostly transport or server errors)
    # here we only log, the or on soap method calls will take care of returning
    on_fault => sub {   
        my($soap, $res) = @_;
        my $errmsg;
        if (ref $res && defined($res->faultstring)) {
            $errmsg = $res->faultstring;
        } else {
            $errmsg = $soap->transport->status;
        }
        syslog("info", "Error in SOAP communication with server: $errmsg");
        &radiusd::radlog(1, "PacketFence DENIED CONNECTION because of SOAP error see syslog for details.");
    };  

#TODO format well and document the fact that we might need re-create the object on error or something
            my $soap = new SOAP::Lite(
                uri   => API_URI,
                proxy => 'https://'.ADMIN_USER.':'.ADMIN_PASS.'@'.WEBADMIN_HOST.'/cgi-bin/pdp.cgi'
            ) or return server_error_handler();

=head1 SUBROUTINES

Of interest to the PacketFence users / developers

=over

=item * authorize - radius calls this method to authorize clients

=cut
sub authorize {
    # For debugging purposes only
    #&log_request_attributes;

    # syslog logging
    openlog("rlm_perl_packetfence", "perror,pid","user");

    my $mac = $RAD_REQUEST{'Calling-Station-Id'};
    # TODO refactoring: change name because its not only a switch, it can be an AP
    # networkelement_ip? networkdevice_ip?
    my $switch_ip = $RAD_REQUEST{'Client-IP-Address'};
    my $user_name = $RAD_REQUEST{'User-Name'};
    my $nas_port_type = $RAD_REQUEST{'NAS-Port-Type'};
    my $port = $RAD_REQUEST{'NAS-Port'};
    my $ssid = find_ssid();
    if (!defined($ssid)) {
        # We were not able to parse SSID. For now, I don't think it's important enough to even log
        # syslog("info", "Unable to parse SSID from request.");
        $ssid = "";
    }

    my $request_is_eap = 0;
    if (exists($RAD_REQUEST{'EAP-Type'})) {
        $request_is_eap = 1;
    }

    if (defined($mac) && $mac ne '') {
        #format MAC
        $mac =~ s/ /0/g;
        $mac =~ s/-/:/g;
        $mac =~ s/\.//g;
        if (length($mac) == 12) {
            $mac = substr($mac,0,2) . ":" . substr($mac,2,2) . ":" . substr($mac,4,2) . ":" . 
                   substr($mac,6,2) . ":" . substr($mac,8,2) . ":" . substr($mac,10,2);
        }
        $mac = lc($mac);
    } else {
        syslog("info", "warning: mac address is empty in this request");
    }

    # some debugging (shown when running radius with -X)
    &radiusd::radlog(1, "PacketFence REQUEST-TYPE: ".$nas_port_type);
    &radiusd::radlog(1, "PacketFence SWITCH: $switch_ip");
    &radiusd::radlog(1, "PacketFence REQUEST IS EAP?: $request_is_eap");
    &radiusd::radlog(1, "PacketFence MAC: ".$mac);
    &radiusd::radlog(1, "PacketFence PORT: ".$port);
    &radiusd::radlog(1, "PacketFence USER: ".$user_name);
    &radiusd::radlog(1, "PacketFence SSID: ".$ssid);

    if (length($mac) == 17) {
        # uncomment following for output of all parameters to syslog (affects performance)
        # syslog("info", "nas port type => $nas_port_type, switch_ip => $switch_ip, EAP => $request_is_eap, ".
        #        "mac => $mac, port => $port, username => $user_name, ssid => $ssid");

        # TODO: switch_ip is no longer a good name, it needs to change
        my $som = $soap->radius_authorize($nas_port_type, $switch_ip, $request_is_eap, 
                                          $mac, $port, $user_name, $ssid)
            or return server_error_handler();

        # did SOAP server returned a fault in the request?
        if ($som->fault) {
            # TODO should we also output $som->faultdetail and $som->faultactor?
            syslog("info", "Error in SOAP communication with server. Error no: ".
                   $som->faultcode." Error msg: ".$som->faultstring);
            &radiusd::radlog(1, "PacketFence DENIED CONNECTION because of SOAP error see syslog for details.");
            return server_error_handler();

        } else {

            # grabbing the result
            # we expect an ARRAY ref from the server
            # The server returns a tuple with element 0 being a response code for Radius and second element 
            # an hash meant to fill the Radius reply (RAD_REPLY). The arrayref is to workaround a quirk 
            # in SOAP::Lite and have everything in result().
            # See http://search.cpan.org/~byrne/SOAP-Lite/lib/SOAP/Lite.pm#IN/OUT,_OUT_PARAMETERS_AND_AUTOBINDING
            my $result = $som->result() or return server_error_handler();
            if (defined($result) && (ref($result) eq 'ARRAY')) {
                my $radius_return_code = shift @$result; # first param 
                my %radius_reply       = @$result; # the rest goes to fill the hash

                if (!defined($radius_return_code)) {
                    syslog("info","No reply in SOAP communication with server. Check server side logs for details.");
                    &radiusd::radlog(1, "PacketFence UNDEFINED RESULT RESPONSE CODE");
                    &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
                    closelog;
                    return RLM_MODULE_FAIL;
                }

                # Assigning returned values to RAD_REPLY
                %RAD_REPLY = %radius_reply;

                if ($radius_return_code == 2 && defined($RAD_REPLY{'Tunnel-Private-Group-ID'})) {
                    syslog("info", "returning vlan ".$RAD_REPLY{'Tunnel-Private-Group-ID'}." "
                        . "to request from $mac port $port");
                    &radiusd::radlog(1, "PacketFence RESULT VLAN: ".$RAD_REPLY{'Tunnel-Private-Group-ID'});
                } else {
                    syslog("info", "request from $mac port $port was not accepted. Check server logs for details");
                    &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
                }

                &radiusd::radlog(1, "PacketFence RESULT RESPONSE CODE: $radius_return_code (2 means OK)");
                # Uncomment for verbose debugging with radius -X
                # use Data::Dumper;
                # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
                # &radiusd::radlog(1, "PacketFence COMPLETE REPLY: ". Dumper(\%radius_reply));
                return $radius_return_code;
            }
        }
    }
    syslog("info", "could not identify MAC in request, returning OK");
    closelog();
    return RLM_MODULE_OK;
}

=item * server_error_handler - called whenever there is a server error beyond PacketFence's control (401, 404, 500)

If a customer wants to degrade gracefully, he should put some logic here to assign good VLANs in a degraded way. Two examples are provided commented in the file.

=cut
sub server_error_handler {
   closelog();
   return RLM_MODULE_FAIL; 

   # for example:
   # send an email
   # set vlan default according to $switch_ip
   # return RLM_MODULE_OK

   # or to fail open:
   # return RLM_MODULE_OK
}

=item * find_ssid - translate radius SSID parameter into a string

SSID are not provided by a standardized parameter name so we encapsulate that complexity here.
If your AP is not supported look in /usr/share/freeradius/dictionary* for vendor specific parameters.
If you add a test here, please consider contributing it back to packetfence:

https://lists.sourceforge.net/lists/listinfo/packetfence-devel

=cut
sub find_ssid {

    if (exists($RAD_REQUEST{'Cisco-AVPair'})) {

        if ($RAD_REQUEST{'Cisco-AVPair'} =~ /^ssid=(.*)$/) { # ex: Cisco-AVPair = "ssid=Inverse-Secure"
            return $1;
        } else {
            syslog("info", "Unable to parse SSID out of Cisco-AVPair: ".$RAD_REQUEST{'Cisco-AVPair'});
            return;
        }
    } else {
        return;
    } 
}

# Function to handle authenticate
sub authenticate {
        # For debugging purposes only
#       &log_request_attributes;

        # TODO cleanup: remove that, it was never done by us (don't forget to return OK)
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

=back

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
