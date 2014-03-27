package pf::radius::msgpackclient;

=head1 NAME

pf::radius::msgpackclient add documentation

=cut

=head1 DESCRIPTION

pf::radius::msgpackclient

=cut

use strict;
use warnings;

use Log::Log4perl;
use WWW::Curl::Easy;
use Data::MessagePack;

use base qw(Exporter);
our @EXPORT = qw(send_msgpack_request build_msgpack_request);

# Configuration parameter
use constant SOAP_PORT => '9090'; #TODO: See note1

sub send_msgpack_request {
    use bytes;
    my ($function,$data) = @_;
    my $response;

    my $request = build_msgpack_request($function,$data);
    my $curl = WWW::Curl::Easy->new;
    my $response_body;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . SOAP_PORT); # TODO: See note1
#    $curl->setopt(CURLOPT_URL, 'http://127.0.0.1:' . $Config{'ports'}{'soap'}); # TODO: See note1
    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: application/x-msgpack']);
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        $response = Data::MessagePack->unpack($response_body);
    } else {
        my $msg = "An error occured while sending a MessagePack request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
        die $msg;
    }

    return $response->[3];
}


sub build_msgpack_request {
    my ($function,$hash) = @_;
    my $request = [0,0,$function,[%$hash]];
    return Data::MessagePack->pack($request);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

