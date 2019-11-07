package pf::pki_provider::packetfence_pfpki;

=head1 NAME

pf::pki_provider::packetfence_pfpki

=cut

=head1 DESCRIPTION

pf::pki_provider::packetfence_pfpki

=cut

use strict;
use warnings;
use Moo;
use pf::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::api::unifiedapiclient;

extends 'pf::pki_provider';

use pf::log;

sub module_description { 'PacketFence PKI NG' }

=head2 profile

The profile to use for the packetfence_pki pki service

=cut

has profile => ( is => 'rw' );

=head2 get_bundle

Get the certificate bundle from the packetfence_pki pki service

=cut

sub get_bundle {
    my ($self,$args) = @_;
    my $logger = get_logger();

    my $email = $args->{'certificate_email'};
    my $cn = $args->{'certificate_cn'};
    my $organisation = $self->organization;
    my $state = $self->state;
    my $profile = $self->profile;
    my $country = $self->country;
    my $certpwd = $args->{'certificate_pwd'};


    pf::api::unifiedapiclient->default_client->call("POST", "/api/v1/pki/cert", {
        "cn"           => $cn,
	"mail"         => $email,
	"organisation" => $organisation,
	"country"      => $country,
	"state"        => $state,
	"profilename"  => $profile,
    });

    my $return = pf::api::unifiedapiclient->default_client->call("GET", "/api/v1/pki/certmgmt/$cn/$certpwd");

    #    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    #    if ($curl_return_code == 0 && $response_code == 200) {
    #        return $response_body;
    #    }
    #    else {
    #        my $curl_error = $curl->errbuf;
    #        $logger->error("certificate could not be acquire, check out logs on the pki. Server replied with $response_body. Curl error : $curl_error");
    #        return undef;
    #    }


}

=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    my ($self, $cn) = @_;
    my $logger = get_logger();

    my $return = pf::api::unifiedapiclient->default_client->call("DELETE", "/api/v1/pki/certmgmt/$cn/1", {
    
		    #    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
		    #    if ($curl_return_code == 0 && $response_code == 200) {
		    #        $logger->info("Revoked certificate for CN $cn");
		    #        return $TRUE;
		    #    }
		    #    else {
		    #        my $curl_error = $curl->errbuf;
		    #        $logger->error("Certificate for CN $cn could not be revoked. Server replied with $response_body. Curl error : $curl_error");
		    #        return $FALSE;
		    #    }


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
