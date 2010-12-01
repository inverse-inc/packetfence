#!/usr/bin/perl

=head1 NAME

packetfence.pm - FreeRadius PacketFence integration module

=head1 DESCRIPTION

packetfence.pm contains the functions necessary to integrate PacketFence and FreeRADIUS

=cut

use strict;
use warnings;
use diagnostics;
use DBI;
use Sys::Syslog;

# Configuration parameters
use constant {
    # FreeRADIUS to PacketFence communications (SOAP Server settings)
    ADMIN_USER     => 'admin',
    ADMIN_PASS     => 'admin',
    WEBADMIN_HOST  => 'localhost:1443',
    API_URI        => 'https://www.packetfence.org/PFAPI' #don't change this unless you know what you are doing
};

require 5.8.8;

# This is very important! Without this script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);

#
# FreeRADIUS return values
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

# when troubleshooting run radius -X and change the following line with: use SOAP::Lite +trace => qw(all), 
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
    proxy => 'https://'.ADMIN_USER.':'.ADMIN_PASS.'@'.WEBADMIN_HOST.'/webapi'
) or return server_error_handler();

=head1 SUBROUTINES

Of interest to the PacketFence users / developers

=over

=item * authorize

RADIUS calls this method to authorize clients.

=cut
sub authorize {
    # For debugging purposes only
    #&log_request_attributes;

    # syslog logging
    openlog("radiusd_pf", "perror,pid", "user");

    # is it EAP-based Wired MAC Authentication?
    if (is_eap_mac_autentication()) {

        # in MAC Authentication the User-Name is the MAC address stripped of all non-hex characters
        my $mac = $RAD_REQUEST{'User-Name'};
        # Password will be the MAC address, we set Cleartext-Password to it so that EAP Auth will perform auth properly
        $RAD_CHECK{'Cleartext-Password'} = $mac;
        my $infolog = "This is a Wired MAC Authentication request with EAP for MAC: $mac. ";
        syslog("info", "$infolog Authentication should pass. File a bug report if it doesn't");
        &radiusd::radlog(1, "$infolog Setting Cleartext-Password to $mac");
        closelog();
        return RLM_MODULE_UPDATED;
    }


    # otherwise, we don't do a thing
    closelog();
    return RLM_MODULE_NOOP;
}

=item * post_auth

Once we authenticated the user's identity, we perform PacketFence's Network Access Control duties

=cut
sub post_auth {

    # syslog logging
    openlog("radiusd_pf", "perror,pid", "user");

    my $mac = $RAD_REQUEST{'Calling-Station-Id'};
    my $port = $RAD_REQUEST{'NAS-Port'};

    #format MAC
    if (defined($mac) && $mac ne '') {
        $mac =~ s/ /0/g;
        $mac =~ s/-/:/g;
        $mac =~ s/\.//g;
        if (length($mac) == 12) {
            $mac = substr($mac,0,2) . ":" . substr($mac,2,2) . ":" . substr($mac,4,2) . ":" . 
                   substr($mac,6,2) . ":" . substr($mac,8,2) . ":" . substr($mac,10,2);
        }
        $mac = lc($mac);
    }

    # invalid MAC, this certainly happens on some type of RADIUS calls, we accept so it'll go on and ask other modules
    if (length($mac) != 17) {
        syslog("info", "warning: mac address is empty or invalid in this request. "
            . "It could be normal on certain radius calls");
        closelog();
        return RLM_MODULE_OK;
    }

    my $som = $soap->radius_authorize(%RAD_REQUEST)
        or return server_error_handler();

    # did SOAP server returned a fault in the request?
    if ($som->fault) {
        return server_error_handler();
    }

    # grabbing the result
    my $result = $som->result() 
        or return server_error_handler();

    # we expect an ARRAY ref from the server
    # The server returns a tuple with element 0 being a response code for Radius and second element 
    # an hash meant to fill the Radius reply (RAD_REPLY). The arrayref is to workaround a quirk 
    # in SOAP::Lite and have everything in result().
    # See http://search.cpan.org/~byrne/SOAP-Lite/lib/SOAP/Lite.pm#IN/OUT,_OUT_PARAMETERS_AND_AUTOBINDING
    if (!defined($result) || !(ref($result) eq 'ARRAY')) {

        # invalid answer
        return invalid_answer_handler();
    }

    # is return code valid?
    my $radius_return_code = shift @$result;
    if (!defined($radius_return_code) || !($radius_return_code > 0 && $radius_return_code < RLM_MODULE_NUMCODES)) {
        return invalid_answer_handler();
    }

    # NORMAL CASE
    # At this point, everything went well and the reply from the server is valid

    # Merging returned values with RAD_REPLY, right-hand side wins on conflicts
    %RAD_REPLY = (%RAD_REPLY, @$result); # the rest of result is the reply hash passed by the radius_authorize

    if ($radius_return_code == 2) {
        if (defined($RAD_REPLY{'Tunnel-Private-Group-ID'})) {
            syslog("info", "returning vlan ".$RAD_REPLY{'Tunnel-Private-Group-ID'}." "
                . "to request from $mac port $port");
            &radiusd::radlog(1, "PacketFence RESULT VLAN: ".$RAD_REPLY{'Tunnel-Private-Group-ID'});
        } else {
            syslog("info", "request from $mac port $port was accepted but no VLAN returned. "
                . "See server logs for details");
            &radiusd::radlog(1, "PacketFence NO RESULT VLAN");
        }
    } else {
        syslog("info", "request from $mac port $port was not accepted but a proper error code was provided. "
            . "Check server side logs for details");
        &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
    }

    &radiusd::radlog(1, "PacketFence RESULT RESPONSE CODE: $radius_return_code (2 means OK)");
    # Uncomment for verbose debugging with radius -X
    # use Data::Dumper;
    # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
    # &radiusd::radlog(1, "PacketFence COMPLETE REPLY: ". Dumper(\%radius_reply));
    closelog();
    return $radius_return_code;
}

=item * server_error_handler

Called whenever there is a server error beyond PacketFence's control (401, 404, 500)

If a customer wants to degrade gracefully, he should put some logic here to assign good VLANs in a degraded way. Two examples are provided commented in the file.

=cut
sub server_error_handler {
   closelog();
   return RLM_MODULE_FAIL; 

   # for example:
   # send an email
   # set vlan default according to $nas_ip
   # return RLM_MODULE_OK

   # or to fail open:
   # return RLM_MODULE_OK
}

=item * invalid_answer_handler

Called whenever an invalid answer is returned from the server

=cut
sub invalid_answer_handler {
    syslog("info","No or invalid reply in SOAP communication with server. Check server side logs for details.");
    &radiusd::radlog(1, "PacketFence UNDEFINED RESULT RESPONSE CODE");
    &radiusd::radlog(1, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
    closelog;
    return RLM_MODULE_FAIL;
}

=item * is_eap_mac_autentication

Returns 1 or 0 based on if query is EAP-based MAC Authentication

EAP-based MAC Authentication is like MAC Authentication except that instead of using a RADIUS-only request 
(like most vendor do) it's using EAP inside RADIUS to authenticate the MAC.
Vendors known to proceed this way: Juniper's MAC RADIUS and Extreme Networks' Netlogin

=cut
sub is_eap_mac_autentication {

    # EAP and User-Name is a MAC address
    if (exists($RAD_REQUEST{'EAP-Type'}) && $RAD_REQUEST{'User-Name'} =~ /[0-9a-fA-F]{12}/) {

        # clean station MAC
        my $mac = $RAD_REQUEST{'Calling-Station-Id'};
        $mac =~ s/ /0/g;
        $mac =~ s/-//g;
        $mac =~ s/://g;
        $mac =~ s/\.//g;
        if (length($mac) == 12) {

            # if Calling MAC and User-Name are the same thing, then we are processing a EAP Mac Auth request
            if ($mac eq $RAD_REQUEST{'User-Name'}) {
                return 1;
            }
        } else {
            my $infolog = "MAC inappropriate for comparison. Can't tell if we are in EAP Wired MAC Auth case.";
            syslog("info", $infolog);
            &radiusd::radlog(1, $infolog);
        }
    }
    return 0;
}

#
# --- Unused FreeRADIUS hooks ---
#

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
