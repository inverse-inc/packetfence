package pf::Authentication::Source::KickboxSource;

=head1 NAME

pf::Authentication::Source::KickboxSource

=cut

=head1 DESCRIPTION

Model definition for a Kickbox authentication source

=cut

use strict;
use warnings;
use Moose;
use JSON::MaybeXS;
use pf::constants;
use pf::config;
use pf::util;
use WWW::Curl::Easy;
use Readonly;
use pf::log;
use URI::Escape::XS qw(uri_escape);
use List::MoreUtils qw(any);
use Email::Valid;
use pf::error qw(is_success);

extends 'pf::Authentication::Source::NullSource';

Readonly our $KICKBOX_HOST => "https://api.kickbox.io";
Readonly our $VERIFY_URI => "/v2/verify";
Readonly our @ACCEPTABLE_RESULTS => qw(deliverable);

has '+type' => (default => 'Kickbox');
has 'api_key' => (isa => 'Str', is => 'rw');
has '+email_required' => (isa => 'Str', is => 'rw', default => 'yes');

sub authenticate {
    my ($self, $username, $password) = @_;
    my $logger = get_logger();

    my $uri = $KICKBOX_HOST.$VERIFY_URI;

    # Checking if it's valid first so we don't do unecessary hits on Kickbox
    unless(Email::Valid->address($username)) {
        $logger->info("$username is not a valid e-mail address. Not verifying with kickbox.io");
        return ($FALSE, "Invalid e-mail");
    }

    my $curl = WWW::Curl::Easy->new;
    my $request = "email=".uri_escape($username)."&apikey=".uri_escape($self->api_key);

    $uri .= "?$request";

    my $response_body = '';
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);

    $logger->info("Calling Kickbox.io service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

    if ($curl_return_code == 0 && is_success($response_code)) {
        my $info = decode_json($response_body);
        if( any {$_ eq $info->{result}} @ACCEPTABLE_RESULTS){
            $logger->info("$info->{result} is acceptable for e-mail address $username. Considering as valid.");
            return ($TRUE, "E-mail is valid according to kickbox.io")
        }
        else {
            $logger->info("$info->{result} is NOT acceptable for e-mail address $username. Considering as invalid.");
            return ($FALSE, "E-mail is not acceptable according to kickbox.io");
        }
    }
    else {
        my $curl_error = $curl->errbuf;
        $logger->error("e-mail could not be validated. Server replied with $response_body. Curl error : $curl_error");
        return ($FALSE, "Error while contacting kickbox.io");
    }


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

