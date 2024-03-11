package pf::pki_provider::packetfence_pki;

=head1 NAME

pf::pki_provider::packetfence_pki

=cut

=head1 DESCRIPTION

pf::pki_provider::packetfence_pki

=cut

use strict;
use warnings;
use Moo;
use pf::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::api::unifiedapiclient;
use pf::dal::key_value_storage;
use pf::error qw(is_success is_error);

extends 'pf::pki_provider';

use pf::log;

sub module_description { 'PacketFence PKI' }

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
    my $locality = $self->locality;
    my $street = $self->streetaddress;
    my $postalcode = $self->postalcode;
    my $streetaddress = $self->streetaddress;

    my $certpwd = $args->{'certificate_pwd'};

    my $value = eval {
        my $return = pf::api::unifiedapiclient->default_client->call("POST", "/api/v1/pki/certs", {
            "cn"             => $cn,
            "mail"           => $email,
            "organisation"   => $organisation,
            "country"        => $country,
            "state"          => $state,
            "locality"       => $locality,
            "postal_code"    => $postalcode,
            "street_address" => $streetaddress,
            "profile_id"     => $profile,
        });
    };
    if ($@) {
        $logger->warn("Certificate creation failed");
        return;
    }
    my $return;
    $value = eval {
        $return = pf::api::unifiedapiclient->default_client->call("GET", "/api/v1/pki/cert/$profile/$cn/download/$certpwd");
    };
    if ($@) {
        $logger->warn("Download certificate failed");
        return;
    }
    return $return;
}

=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    my ($self, $cn) = @_;
    my $logger = get_logger();

    my $value = eval {
        my $return = pf::api::unifiedapiclient->default_client->call("DELETE", "/api/v1/pki/cert/$self->{'profile'}/$cn/1");
    };
    if ($@) {
        $logger->debug("Unable to revoke certificate associated with this cn $cn");
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
