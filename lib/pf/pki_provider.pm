package pf::pki_provider;
=head1 NAME

pf::pki_provider add documentation

=cut

=head1 DESCRIPTION

pf::pki_provider

=cut

use strict;
use warnings;
use Moo;
use pf::log;
use pf::constants;

has id => (is => 'rw', required => 1);

has ca_cert_path => (is => 'rw');

has server_cert_path => (is => 'rw');

has ca_cert => (is => 'ro' , builder => 1, lazy => 1);

has server_cert => (is => 'ro' , builder => 1, lazy => 1);

has cn_attribute => (is => 'rw');

has cn_format => (is => 'rw', default => '%s');

has revoke_on_unregistration => (is => 'rw', default => 'N');

=head2 country

What country to use for the certificate

=cut

has country => ( is => 'rw' );

=head2 state

What state to use for the certificate

=cut

has state => ( is => 'rw' );

=head2 locality

What locality to use for the certificate

=cut

has locality => ( is => 'rw' );

=head2 organization

What organization to use for the certificate

=cut

has organization => ( is => 'rw' );

=head2 organizational_unit

What organizational_unit to use for the certificate

=cut

has organizational_unit => ( is => 'rw' );


=head2 module_description

Returns the module description

Parent returns empty so that the factory use the own child module name if not defined in child module

=cut

sub module_description { '' }

=head2 get_bundle

Get the certificate bundle from the pki

=cut

sub get_bundle {
    get_logger->error("get_bundle is not implemented for this PKI provider. Certificate generation will fail.");
    return $FALSE;
}

=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    get_logger->error("revoke is not implemented for this PKI provider. Certificate generation will fail.");
    return $FALSE;
}

=head2 _build_ca_cert

Builds an X509 object the ca_cert_path

=cut

sub _build_ca_cert {
    my ($self) = @_;
    return Crypt::OpenSSL::X509->new_from_file($self->ca_cert_path);
}

=head2 _build_server_cert

Builds an X509 object the server_cert_path

=cut

sub _build_server_cert {
    my ($self) = @_;
    return Crypt::OpenSSL::X509->new_from_file($self->server_cert_path);
}


=head2 _raw_cert_string

Extracts the certificate content minus the ascii armor

=cut

sub _raw_cert_string {
    my ($self, $cert) = @_;
    my $cert_pem = $cert->as_string();
    $cert_pem =~ s/-----END CERTIFICATE-----\n.*//smg;
    $cert_pem =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    return $cert_pem;
}

sub _cert_cn {
    my ($self, $cert) = @_;
    if($cert->subject =~ /CN=(.*?)(,|$)/g){
        return $1;
    }
    else {
        get_logger->error("Cannot find CN of server certificate at ".$self->ca_cert_path);
        return undef;
    }

}

=head2 raw_ca_cert_string

Get the ca certificate content minus the ascii armor

=cut

sub raw_ca_cert_string {
    my ($self) = @_;
    return $self->_raw_cert_string($self->ca_cert);
}

=head2 raw_server_cert_string

Get the server certificate content minus the ascii armor

=cut

sub raw_server_cert_string {
    my ($self) = @_;
    return $self->_raw_cert_string($self->server_cert);
}

sub server_cn {
    my ($self) = @_;
    my $cn = $self->_cert_cn($self->server_cert);
    if(defined($cn)){
        return $cn;
    }
    else {
        get_logger->error("cannot find cn of server certificate at ".$self->server_cert_path);
    }
}

sub ca_cn {
    my ($self) = @_;
    my $cn = $self->_cert_cn($self->ca_cert);
    if(defined($cn)){
        return $cn;
    }
    else {
        get_logger->error("cannot find cn of ca certificate at ".$self->ca_cert_path);
    }
}

sub user_cn {
    my ($self, $node_info) = @_;
    my $cn = sprintf($self->cn_format, $node_info->{$self->cn_attribute});
    if( defined($cn) ) {
        return $cn;
    }
    else {
        get_logger->info("Can't find attribute based CN for mac $node_info->{mac} Searching for attribute $self->cn_attribute.");
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
