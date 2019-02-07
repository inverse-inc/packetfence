package pf::radius::soapclient;

=head1 NAME

pf::radius::soapclient add documentation

=cut

=head1 DESCRIPTION

pf::radius::soapclient

=cut

use strict;
use warnings;

use HTML::Entities;
use WWW::Curl::Easy;
use XML::Simple;
use Encode qw(decode);
$XML::Simple::PREFERRED_PARSER = 'XML::LibXML::SAX';

use base qw(Exporter);
our @EXPORT = qw(send_soap_request build_soap_request);

# Configuration parameter
use constant SOAP_PORT => '9090'; #TODO: See note1
use constant API_URI => 'https://www.packetfence.org/PFAPI'; # don't change this unless you know what you are doing

sub send_soap_request {
    my ($function,$data) = @_;
    my $response;

    my $request = build_soap_request($function,$data);
    my $curl = WWW::Curl::Easy->new;
    my $response_body;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT); # TODO: See note1
#    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'}); # TODO: See note1
    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: text/xml; charset=UTF-8',"Request: $function"]);
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $xml = new XML::Simple;
        $response = $xml->XMLin($response_body, NoAttr => 1);
    }
    else {
        my $msg = "An error occured while sending a SOAP request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
        die $msg;
    }

    return $response;
}

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

sub build_soap_request {
    my ($function,$hash) = @_;
    my $request_prefix = "<?xml version='1.0' encoding='UTF-8'?><soap:Envelope xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:soapenc='http://schemas.xmlsoap.org/soap/encoding/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' soap:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/'><soap:Body><$function xmlns='" . API_URI . "'>";
    my $request_suffix = "</$function></soap:Body></soap:Envelope>";
    my $request = $request_prefix . build_soap_elements($hash) . $request_suffix;
    return $request;
}

sub build_soap_elements {
    my ($hash) = @_;
    my $counter = 1;    # looks like this one is not mandatory, we still use it to keep track of keys/values
    my $content = '';
    while ( my ($key,$value) =  each %$hash ) {
        # RADIUS Vendor Specific Attributes (VSA) are in the form of an ARRAY which is special in SOAP...
        if ( ref($value) eq 'ARRAY' ) {
            my $array_content = '';
            my $array_counter = 0;  # that one is actually important...
            $content .= build_soap_string("c-gensym$counter",$key);
            my $array_size = @$value;
            foreach my $array_value ( @$value ) {
                $array_content .= build_soap_string("item",$array_value);
                $counter++;  # looks like this one is not mandatory, we still use it to keep track of keys/values
            }
            $content .=
                "<soapenc:Array soapenc:arrayType=\"xsd:string[$array_size]\" xsi:type=\"soapenc:Array\">$array_content</soapenc:Array>";
        } else {
            my $name = "c-gensym$counter";
            $content .= build_soap_string($name,$key);
            $content .= build_soap_string($name,$value);
            $counter += 1;  # looks like this one is not mandatory, we still use it to keep track of keys/values
        }
    }
    return $content;
}

sub build_soap_string {
    my ($name,$value) = @_;
    $value = encode_entities(decode('utf8',$value));
    return "<$name xsi:type=\"xsd:string\">$value</$name>";
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

