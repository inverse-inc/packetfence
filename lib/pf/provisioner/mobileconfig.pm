package pf::provisioner::mobileconfig;
=head1 NAME

pf::provisioner::mobileconfig add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::mobileconfig

=cut

use strict;
use warnings;

use Crypt::SMIME;
use MIME::Base64 qw(decode_base64);

use Moo;
extends 'pf::provisioner';

=head1 Atrributes

=head2 oses

The set the default OS to IOS

=cut

# Will always ignore the oses parameter provided and use ['Apple iPod, iPhone or iPad']
has 'oses' => (is => 'ro', default => sub { ['Apple iPod, iPhone or iPad', 'Mac OS X'] }, coerce => sub { ['Apple iPod, iPhone or iPad', 'Mac OS X'] });

=head2 ssid

The ssid broadcast name

=cut

has ssid => (is => 'rw');

=head2 passcode

Passphrase if no eap/not open network

=cut

has passcode => (is => 'rw');

=head2 security_type

Security encryption used

=cut

has security_type => (is => 'rw');

=head2 eap_type

The EAP type

=cut

has eap_type => (is => 'rw');

# make it skip deauth by default

has skipDeAuth => (is => 'rw', default => sub{ 1 });

has for_username => (is => 'rw');

=head2 company

Organisation information

=cut

has company => (is => 'rw');

=head2 reversedns

Organisation reversedns

=cut

has reversedns => (is => 'rw');


=head2 ca_cert

The CA certificate in PEM format

=cut

has ca_cert => (is => 'rw');

=head2 certificate

The certificate for signing in PEM format

=cut

has certificate => (is => 'rw');

=head2 private_key

The private key for signing in PEM format

=cut

has private_key => (is => 'rw');

=head2 can_sign_profile

Enabled or disables the signing of the profile

=cut

has can_sign_profile => (is => 'rw', default => sub { 0 } );

=head1 METHODS

=head2 authorize

always authorize

=cut

sub authorize {
    my ($self, $mac) = @_;
    my $info = pf::node::node_view($mac);
    $self->for_username($info->{pid});
    return 1;
}


=head2 sign_profile

Sign the profile with private key and cert

=cut

sub sign_profile {
    my ($self, $content) = @_;
    my $smime = Crypt::SMIME->new();
    $smime->setPrivateKey($self->private_key, $self->certificate);
    if($self->ca_cert) {
        $smime->setPublicKey($self->ca_cert);
    }
    return decode_base64($smime->signonly_attached($content));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
