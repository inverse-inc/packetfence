#!/usr/bin/perl

=head1 NAME

packetfence.pm - FreeRADIUS PacketFence integration module

=head1 DESCRIPTION

This module forwards normal RADIUS requests to PacketFence.

=head1 NOTES

Note1:

Our pf::config package is loading all kind of stuff and should be reworked a bit. We need to use that package to load
configuration parameters from the configuration file. Until the package is cleaned, we will define the configuration
parameter here.

Once cleaned:

- Uncommented line: use pf::config

- Remove line: use constant SOAP_PORT => '9090';

- Remove line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT);

- Uncomment line: $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'});

Search for 'note1' to find the appropriate lines.

=cut

use strict;
use warnings;


use lib '/usr/local/pf/lib/';

#use pf::config; # TODO: See note1
use pf::radius::constants;
use pf::radius::soapclient;
use pf::util::freeradius qw(clean_mac);

# Configuration parameter
use constant SOAP_PORT => '9090'; #TODO: See note1
use constant API_URI => 'https://www.packetfence.org/PFAPI'; # don't change this unless you know what you are doing

require 5.8.8;

# This is very important! Without this, the script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);

=head1 SUBROUTINES

=over

=item * authorize

RADIUS calls this method to authorize clients.

=cut

sub authorize {
    # For debugging purposes only
    #&log_request_attributes;

    # is it EAP-based Wired MAC Authentication?
    if ( is_eap_mac_authentication() ) {
        # in MAC Authentication the User-Name is the MAC address stripped of all non-hex characters
        my $mac = $RAD_REQUEST{'User-Name'};
        # Password will be the MAC address, we set Cleartext-Password so that EAP Auth will perform auth properly
        $RAD_CHECK{'Cleartext-Password'} = $mac;
        &radiusd::radlog($RADIUS::L_DBG, "This is a Wired MAC Authentication request with EAP for MAC: $mac. Authentication should pass. File a bug report if it doesn't");
        return $RADIUS::RLM_MODULE_UPDATED;
    }

    # otherwise, we don't do a thing
    return $RADIUS::RLM_MODULE_NOOP;
}

=item * post_auth

Once we authenticated the user's identity, we perform PacketFence's Network Access Control duties

=cut

sub post_auth {
    my $radius_return_code = $RADIUS::RLM_MODULE_REJECT;
    eval {
        my $mac = clean_mac($RAD_REQUEST{'Calling-Station-Id'});
        my $port = $RAD_REQUEST{'NAS-Port'};

        # invalid MAC, this certainly happens on some type of RADIUS calls, we accept so it'll go on and ask other modules
        if ( length($mac) != 17 ) {
            &radiusd::radlog($RADIUS::L_INFO, "MAC address is empty or invalid in this request. It could be normal on certain radius calls");
            return $RADIUS::RLM_MODULE_OK;
        }

        my $data = send_soap_request("radius_authorize",\%RAD_REQUEST);
        if($data) {

            my $elements = $data->{'soap:Body'}->{'radius_authorizeResponse'}->{'soapenc:Array'}->{'item'};

            # Get RADIUS return code
            $radius_return_code = shift @$elements;

            if ( !defined($radius_return_code) || !($radius_return_code > $RADIUS::RLM_MODULE_REJECT && $radius_return_code < $RADIUS::RLM_MODULE_NUMCODES) ) {
                return invalid_answer_handler();
            }

            # Merging returned values with RAD_REPLY, right-hand side wins on conflicts
            my $attributes = {@$elements};
            %RAD_REPLY = (%RAD_REPLY, %$attributes); # the rest of result is the reply hash passed by the radius_authorize
        } else {
            return server_error_handler();
        }

        # For debugging purposes
        #&radiusd::radlog($RADIUS::L_INFO, "radius_return_code: $radius_return_code");

        if ( $radius_return_code == $RADIUS::RLM_MODULE_OK ) {
            if ( defined($RAD_REPLY{'Tunnel-Private-Group-ID'}) ) {
                &radiusd::radlog($RADIUS::L_AUTH, "Returning vlan ".$RAD_REPLY{'Tunnel-Private-Group-ID'}." "
                    . "to request from $mac port $port");
            } else {
                &radiusd::radlog($RADIUS::L_AUTH, "request from $mac port $port was accepted but no VLAN returned. "
                    . "This could be normal. See server logs for details.");
            }
        } else {
            &radiusd::radlog($RADIUS::L_INFO, "request from $mac port $port was not accepted but a proper error code was provided. "
                . "Check server side logs for details");
        }

        &radiusd::radlog($RADIUS::L_DBG, "PacketFence RESULT RESPONSE CODE: $radius_return_code (2 means OK)");

        # Uncomment for verbose debugging with radius -X
        # Warning: This is a native module so you shouldn't run it with radiusd in threaded mode (default)
        # use Data::Dumper;
        # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
        # &radiusd::radlog($RADIUS::L_DBG, "PacketFence COMPLETE REPLY: ". Dumper(\%RAD_REPLY));
    };

    return $radius_return_code;
}

=item * server_error_handler

Called whenever there is a server error beyond PacketFence's control (401, 404, 500)

If a customer wants to degrade gracefully, he should put some logic here to assign good VLANs in a degraded way. Two examples are provided commented in the file.

=cut

sub server_error_handler {
   # no need to log here as on_fault is already triggered
   return $RADIUS::RLM_MODULE_FAIL;

   # TODO provide complete examples
   # for example:
   # send an email
   # set vlan default according to $nas_ip
   # return $RADIUS::RLM_MODULE_OK

   # or to fail open:
   # return $RADIUS::RLM_MODULE_OK
}

=item * invalid_answer_handler

Called whenever an invalid answer is returned from the server

=cut

sub invalid_answer_handler {
    &radiusd::radlog($RADIUS::L_ERR, "No or invalid reply in SOAP communication with server. Check server side logs for details.");
    &radiusd::radlog($RADIUS::L_DBG, "PacketFence UNDEFINED RESULT RESPONSE CODE");
    &radiusd::radlog($RADIUS::L_DBG, "PacketFence RESULT VLAN COULD NOT BE DETERMINED");
    return $RADIUS::RLM_MODULE_FAIL;
}

=item * is_eap_mac_authentication

Returns TRUE (1) or FALSE (0) based on if query is EAP-based MAC Authentication

EAP-based MAC Authentication is like MAC Authentication except that instead of using a RADIUS-only request
(like most vendor do) it's using EAP inside RADIUS to authenticate the MAC.

=cut

sub is_eap_mac_authentication {
    # EAP and User-Name is a MAC address
    if ( exists($RAD_REQUEST{'EAP-Type'}) && $RAD_REQUEST{'User-Name'} =~ /[0-9a-fA-F]{12}/ ) {
        # clean station MAC
        my $mac = lc($RAD_REQUEST{'Calling-Station-Id'});
        $mac =~ s/ /0/g;
        # trim garbage
        $mac =~ s/[\s\-\.:]//g;

        if ( length($mac) == 12 ) {
            # if Calling MAC and User-Name are the same thing, then we are processing a EAP Mac Auth request
            if ($mac eq lc($RAD_REQUEST{'User-Name'})) {
                return 1;
            }
        } else {
            &radiusd::radlog($RADIUS::L_DBG, "MAC inappropriate for comparison. Can't tell if we are in EAP Wired MAC Auth case.");
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
        &radiusd::radlog($RADIUS::L_DBG, "rlm_perl::Detaching. Reloading. Done.");
}

#
# Some functions that can be called from other functions
#

sub log_request_attributes {
        # This shouldn't be done in production environments!
        # This is only meant for debugging!
        for (keys %RAD_REQUEST) {
                &radiusd::radlog($RADIUS::L_INFO, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
        }
}

=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 COPYRIGHT

Copyright (C) 2002  The FreeRADIUS server project

Copyright (C) 2002  Boian Jordanov <bjordanov@orbitel.bg>

Copyright (C) 2006-2010, 2013 Inverse inc.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
