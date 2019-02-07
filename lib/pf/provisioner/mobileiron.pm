package pf::provisioner::mobileiron;
=head1 NAME

pf::provisioner::mobileiron add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::mobileiron

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use WWW::Curl::Easy;
use JSON::MaybeXS qw( decode_json );
use pf::util qw(clean_mac);
use XML::Simple;
use pf::log;
use pf::ip4log;
use MIME::Base64;

=head1 Atrributes

=head2 username

Username of a user that has the API rights

=cut

has username => (is => 'rw');

=head2 password

Password of a user who has the API rights

=cut

has password => (is => 'rw');

=head2 host

Host of the mobileiron web API
When it's in the cloud append the path to the instance
EX : m.mobileiron.net/inverseca

=cut

has host => (is => 'rw');

=head2 android_download_uri

The URI to download the Android agent

=cut

has android_download_uri => (is => 'rw');

=head2 ios_download_uri

The URI to download the IOS agent

=cut

has ios_download_uri => (is => 'rw');

=head2 windows_phone_download_uri

The URI to download the windows agent

=cut

has windows_phone_download_uri => (is => 'rw');

=head2 boarding_host

The host that is used for onboarding of devices

=cut

has boarding_host => (is => 'rw');

=head2 boarding_port

The port that is used for onboarding of devices

=cut

has boarding_port => (is => 'rw');

sub get_device_info{
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    my $mi_mac = $mac;
    $mi_mac =~ s/://g;
    $mi_mac = uc($mi_mac);

    my $curl = WWW::Curl::Easy->new;
    my $url = 'https://' . $self->host . '/api/v1/dm/devices/mac/'.$mi_mac;

    my $user_pass_base_64 = encode_base64("$self->{username}:$self->{password}", "");

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(),["Authorization: Basic $user_pass_base_64", 'Accept: application/json']);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version


    if ($curl_info == 200){
        my $info = decode_json($response_body);
        return $info;
    }
    elsif ($curl_info == 404){
        my $info;
        eval {
            $info = decode_json($response_body);
        };
        if (defined($info) && $info->{totalCount} == 0){
            $logger->info("The device $mac wasn't found in mobileiron");
            return 0;
        }
        else{
            $logger->error("The URL used for the mobileiron API seems invalid. Validate the configuration.");
            return $pf::provisioner::COMMUNICATION_FAILED;
        }
    }
    else{
        $logger->error("There was an error validating $mac with MobileIron. Got HTTP code $curl_info");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

sub validate_mac_is_compliant{
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $info = $self->get_device_info($mac);
    if (defined($info) && ($info != $pf::provisioner::COMMUNICATION_FAILED && $info != 0)){
        if ($info->{device}->{compliance} == 0){
            $logger->info("Device $mac was found as compliant");
            return 1;
        }
        else{
            $logger->info("Device $mac was found, but is not compliant");
            return 0;
        }
    }
    else{
        return $info;
    }
}

sub authorize {
    my ($self,$mac) = @_;
    my $logger = $self->logger;
    my $ip = pf::ip4log::mac2ip($mac);
    $logger->info("Validating if $mac is compliant in mobileiron");
    return $self->validate_mac_is_compliant($mac);

}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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
