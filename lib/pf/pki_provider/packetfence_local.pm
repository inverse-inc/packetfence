package pf::pki_provider::packetfence_local;

=head1 NAME

pf::pki_provider::packetfence_local

=cut

=head1 DESCRIPTION

PacketFence Local (packetfence_local) is a local "PKI" provider allowing a locally generated end-user certificate to be used by the provisionner portal flow.

=cut

use strict;
use warnings;

use Crypt::OpenSSL::PKCS12;
use Moo;

use pf::constants;
use pf::log;

extends 'pf::pki_provider';

sub module_description { 'PacketFence Local' }

=head1 ATTRIBUTE(S)

=head2 revoke_on_unregistration

Overrided to disable this feature

=cut

has '+revoke_on_unregistration' => ( is => 'ro', default => 'N' );

=head2 client_cert_path

End-user client certificate path

=cut

has 'client_cert_path' => ( is => 'rw' );

=head2 client_key_path

End-user client key path

=cut

has 'client_key_path' => ( is => 'rw' );

=head1 METHOD(S)

=head2 get_bundle

Get the certificate bundle using the provided client certificate/key path

=cut

sub get_bundle {
    my ($self,$args) = @_;
    my $logger = get_logger();

    my $pkcs12 = Crypt::OpenSSL::PKCS12->new;
    return $pkcs12->create_as_string($self->client_cert_path, $self->client_key_path, $args->{'certificate_pwd'});
}

=head2 user_cn

Get the user CN.

In the current case, user CN should be certificate CN

=cut

sub user_cn {
    my ( $self ) = @_;

    my $cert = Crypt::OpenSSL::X509->new_from_file($self->client_cert_path);
    if($cert->subject =~ /CN=(.*?),/g){
        return $1;
    }
    else {
        get_logger->error("Cannot find CN of client certificate at ".$self->client_cert_path);
        return undef;
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
