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
use pf::log;
use pf::constants;
use fingerbank::Constant;

use pf::person;

use Crypt::GeneratePassword qw(word);

use Moo;
extends 'pf::provisioner';

=head1 Atrributes

=head2 enforce

If the provisioner has to be enforced on each connection

=cut

has 'enforce' => (is => 'rw', default => sub { 0 });

=head2 oses

The set the default OS to IOS

=cut

# Will always ignore the oses parameter provided and use ['Apple iPod, iPhone or iPad']
has 'oses' => (is => 'ro', default => sub { [$fingerbank::Constant::PARENT_IDS{IOS}, $fingerbank::Constant::PARENT_IDS{MACOS}] }, coerce => sub { [$fingerbank::Constant::PARENT_IDS{IOS}, $fingerbank::Constant::PARENT_IDS{MACOS}] });

=head2 broadcast

Is the ssid broadcasting

=cut

has broadcast => (is => 'rw');

=head2 ssid

The ssid broadcast name

=cut

has ssid => (is => 'rw');

=head2 passcode

Passphrase if no eap/not open network

=cut

has passcode => (is => 'rw');

=head2 dpsk

Does DPSK need to be activated

=cut

has dpsk => (is => 'rw');

=head2 psk_size

psk key length

=cut

has psk_size => (is => 'rw');

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

=head2 cert_chain

The certificate chain for signing in PEM format

=cut

has cert_chain => (is => 'rw');

=head2 cert_sign

The certificate for signing in PEM format

=cut

has certificate  => (is => 'rw');

=head2 private_key

The private key for signing in PEM format

=cut

has private_key => (is => 'rw');

=head2 profile_template

The template to use for profile

=cut

has profile_template => (is => 'rw', lazy => 1, builder =>1 );

=head2 can_sign_profile

Enabled or disables the signing of the profile

=cut

has can_sign_profile => (is => 'rw', default => sub { 0 } );

has server_certificate_path => (is => 'rw');

has server_certificate => (is => 'ro' , builder => 1, lazy => 1);

=head1 METHODS

=head2 _build_server_cert

Builds an X509 object the server_cert_path

=cut

sub _build_server_certificate {
    my ($self) = @_;
    return Crypt::OpenSSL::X509->new_from_file($self->server_certificate_path);
}

sub _raw_server_cert_string {
    my ($self, $cert) = @_;
    my $cert_pem = $cert->as_string();
    $cert_pem =~ s/-----END CERTIFICATE-----\n.*//smg;
    $cert_pem =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    return $cert_pem;
}

sub _certificate_cn {
    my ($self, $cert) = @_;
    if($cert->subject =~ /CN=(.*?)(,|$)/g){
        return $1;
    }
    else {
        get_logger->error("Cannot find CN of server certificate at ".$self->server_certificate_path);
        return undef;
    }
}

=head2 raw_server_cert_string

Get the server certificate content minus the ascii armor

=cut

sub raw_server_cert_string {
    my ($self) = @_;
    return $self->_raw_server_cert_string($self->server_certificate);
}

sub server_certificate_cn {
    my ($self) = @_;
    my $cn = $self->_certificate_cn($self->server_certificate);
    if(defined($cn)){
        return $cn;
    }
    else {
        get_logger->error("cannot find cn of server certificate at ".$self->server_certificate_path);
    }
}

=head2 authorize

always authorize

=cut

sub authorize {
    my ($self, $mac) = @_;
    my $info = pf::node::node_view($mac);
    unless($info->{pid} eq $default_pid) {
        $self->for_username($info->{pid});
    }
    return $FALSE;
}


=head2 sign_profile

Sign the profile with private key and cert

=cut

sub sign_profile {
    my ($self, $content) = @_;
    my $smime = Crypt::SMIME->new();
    $smime->setPrivateKey($self->private_key, $self->certificate);
    if($self->cert_chain) {
        $smime->setPublicKey($self->cert_chain);
    }
    return decode_base64($smime->signonly_attached($content));
}

=head2 _build_profile_template

Creates a template from the eap type

=cut

sub _build_profile_template {
    my ($self) = @_;
    my $eap_type = $self->eap_type;
    if (defined($eap_type)) {
        if ($eap_type == 13) {
            return "wireless-profile-tls.xml";
        } elsif ($eap_type == 25) {
            return "wireless-profile-peap.xml";
        }
    } 
    return "wireless-profile-noeap.xml";
}

sub generate_dpsk {
    my ($self,$username) = @_;
    my $person = person_view($username);
    if (defined $person->{psk} && $person->{psk} ne '') {
        get_logger->debug("Returning psk key $person->{psk} for user $username");
        return $person->{psk};
    }
    else {
        my $psk_size;
        if ($self->psk_size >= 8) {
            $psk_size = $self->psk_size;
        } else {
            $psk_size = 8;
            get_logger->info("PSK key redefined to 8");
        }
        my $psk = word(8,$psk_size);
        person_modify($username,psk => $psk);
        get_logger->info("PSK key has been generated for user ".$username);
        get_logger->debug("Returning psk key $psk for user $username");
        return $psk;
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
