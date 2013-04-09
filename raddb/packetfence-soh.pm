#!/usr/bin/perl

=head1 NAME

packetfence-soh.pm - FreeRADIUS PacketFence integration module for SoH support

=head1 DESCRIPTION

This module forwards SoH authorization requests to PacketFence.

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

use WWW::Curl::Easy;
use XML::Simple;

use lib '/usr/local/pf/lib/';

#use pf::config; # TODO: See note1
use pf::radius::constants;

# Configuration parameter
use constant SOAP_PORT => '9090'; #TODO: See note1
use constant API_URI => 'https://www.packetfence.org/PFAPI'; # don't change this unless you know what you are doing

require 5.8.8;

# This is very important! Without this, the script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);


=head1 SUBROUTINES

=over

=item * authorize

This function is called to evaluate and react to an SoH packet. It is
the only callback available inside an SoH virtual server.

=cut
sub authorize {
    # Build the SOAP request manually (using CURL)
    # We use CURL to manually build the SOAP request rather than using an existing SOAP module due to the fact that
    # the SOAP module is not threadsafe.
    #
    # SOAP request sample:
        # <?xml version="1.0" encoding="UTF-8"?>
        # <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        # <soap:Body>
        # <soh_authorize xmlns="https://www.packetfence.org/PFAPI">
        # <c-gensym1 xsi:type="xsd:string">NAS-Port-Type</c-gensym1>
        # <c-gensym1 xsi:type="xsd:string">Wireless-802.11</c-gensym1>
        # <c-gensym2 xsi:type="xsd:string">SoH-Supported</c-gensym2>
        # <c-gensym2 xsi:type="xsd:string">no</c-gensym2>
        # <c-gensym3 xsi:type="xsd:string">Service-Type</c-gensym3>
        # <c-gensym3 xsi:type="xsd:string">Login-User</c-gensym3>
        # <c-gensym4 xsi:type="xsd:string">Calling-Station-Id</c-gensym4>
        # <c-gensym4 xsi:type="xsd:string">001b.b18b.8213</c-gensym4>
        # <c-gensym5 xsi:type="xsd:string">Called-Station-Id</c-gensym5>
        # <c-gensym5 xsi:type="xsd:string">001b.2a95.8771</c-gensym5>
        # <c-gensym6 xsi:type="xsd:string">FreeRADIUS-Proxied-To</c-gensym6>
        # <c-gensym6 xsi:type="xsd:string">127.0.0.1</c-gensym6>
        # <c-gensym7 xsi:type="xsd:string">User-Name</c-gensym7>
        # <c-gensym7 xsi:type="xsd:string">host/TESTINGLAPTOP.inverse.local</c-gensym7>
        # <c-gensym8 xsi:type="xsd:string">NAS-Identifier</c-gensym8>
        # <c-gensym8 xsi:type="xsd:string">ap</c-gensym8>
        # <c-gensym9 xsi:type="xsd:string">NAS-IP-Address</c-gensym9>
        # <c-gensym9 xsi:type="xsd:string">10.0.0.199</c-gensym9>
        # <c-gensym10 xsi:type="xsd:string">NAS-Port</c-gensym10>
        # <c-gensym10 xsi:type="xsd:string">345</c-gensym10>
        # <c-gensym11 xsi:type="xsd:string">Framed-MTU</c-gensym11>
        # <c-gensym11 xsi:type="xsd:string">1400</c-gensym11>
        # </soh_authorize>
        # </soap:Body>
        # </soap:Envelope>

    my $curl = WWW::Curl::Easy->new;
    my $request_prefix = '<?xml version="1.0" encoding="UTF-8"?><soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><soap:Body><soh_authorize xmlns="' . API_URI . '">';

    my $request_content = '';
    my $counter = 1;    # looks like this one is not mandatory, we still use it to keep track of keys/values

    foreach my $key ( keys %RAD_REQUEST ) {
        # RADIUS Vendor Specific Attributes (VSA) are in the form of an ARRAY which is special in SOAP...
        if ( ref($RAD_REQUEST{$key}) eq 'ARRAY' ) {
            my $array_content = '';
            my $array_counter = 0;  # that one is actually important...
            $request_content = $request_content .
                "<c-gensym$counter xsi:type=\"xsd:string\">$key</c-gensym$counter>";
            foreach my $array_value ( @{$RAD_REQUEST{$key}} ) {
                $array_counter += 1;    # that one is actually important...
                $array_content = $array_content . "<item xsi:type=\"xsd:string\">$array_value</item>";
                $counter += 1;  # looks like this one is not mandatory, we still use it to keep track of keys/values
            }
            $request_content = $request_content .
                "<soapenc:Array soapenc:arrayType=\"xsd:string[$array_counter]\" xsi:type=\"soapenc:Array\">";
            $request_content = $request_content . $array_content;
            $request_content = $request_content . "</soapenc:Array>";
        } else {
            $request_content = $request_content .
                "<c-gensym$counter xsi:type=\"xsd:string\">$key</c-gensym$counter>";
            $request_content = $request_content .
                "<c-gensym$counter xsi:type=\"xsd:string\">$RAD_REQUEST{$key}</c-gensym$counter>";
            $counter += 1;  # looks like this one is not mandatory, we still use it to keep track of keys/values
        }
    }

    my $request_suffix = '</soh_authorize></soap:Body></soap:Envelope>';

    my $request = $request_prefix . $request_content . $request_suffix;

    my $response_body;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT); # TODO: See note1
#    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'}); # TODO: See note1
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;
    my $radius_return_code = $RADIUS::RLM_MODULE_REJECT;

    # For debugging purposes
    #&radiusd::radlog($RADIUS::L_INFO, "curl_return_code: $curl_return_code");

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $xml = new XML::Simple;
        my $data = $xml->XMLin($response_body, NoAttr => 1);

        my $elements = $data->{'soap:Body'}->{'soh_authorizeResponse'}->{'soapenc:Array'}->{'item'};

        # Get RADIUS SoH return code
        $radius_return_code = shift @$elements;

        if ( !defined($radius_return_code) || !($radius_return_code > $RADIUS::RLM_MODULE_REJECT && $radius_return_code < $RADIUS::RLM_MODULE_NUMCODES) ) {
            return $RADIUS::RLM_MODULE_FAIL;
        }
    } else {
        return $RADIUS::RLM_MODULE_FAIL;
    }

    &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth RESULT RESPONSE CODE: $radius_return_code (2 means OK)");

    # Uncomment for verbose debugging with radius -X
    # Warning: This is a native module so you shouldn't run it with radiusd in threaded mode (default)
    # use Data::Dumper;
    # $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0; # pretty output for rad logs
    # &radiusd::radlog($RADIUS::L_DBG, "StatementOfHealth COMPLETE REPLY: ". Dumper(\%RAD_REPLY));

    return $radius_return_code;
}


=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 COPYRIGHT

Copyright (C) 2011-2013 Inverse inc.

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
