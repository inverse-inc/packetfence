package pf::UnifiedApi::Controller::Config::Certificates;

=head1 NAME

pf::UnifiedApi::Controller::Config::Certificates - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Certificates



=cut

use strict;
use warnings;
use pf::ssl;
use File::Slurp qw(read_file);
use pf::error qw(is_error);
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::file_paths qw(
    $server_cert
    $server_key
    $radius_server_cert
    $radius_ca_cert
    $radius_server_key
);

my $CERT_DELIMITER = "-----END CERTIFICATE-----";

my %CERTS_MAP = (
    http => {
        cert_file => $server_cert,
        key_file => $server_key,
        handle_update => \&http_update,
    },
    radius => {
        cert_file => $radius_server_cert,
        ca_file => $radius_ca_cert,
        key_file => $radius_server_key,
        handle_update => \&radius_update,
    },
);

=head2 resource

Validate the resource

=cut

sub resource {
    my ($self) = @_;
    my $id = $self->stash->{certificate_id};
    unless (defined($self->resource_config($id))) {
        return $self->render_error("404", "Item ($id) not found");
    }

    return 1;
}

sub resource_config {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    return $CERTS_MAP{$certificate_id};
}

sub resource_info {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    my $config = $self->resource_config($certificate_id);
    
    my $certs = read_file($config->{cert_file});
    my @certs = map { $_ . $CERT_DELIMITER} split($CERT_DELIMITER, $certs);

    # The last element should be discarded due to the way the certs are extracted (split) above
    pop @certs;

    if(exists($config->{ca_file})) {
        my $ca = read_file($config->{ca_file});
        push @certs, $ca;
    }

    my $cert = shift @certs;

    my $x509_cert = pf::ssl::x509_from_string($cert);
    my @cas = map { pf::ssl::x509_from_string($_) } @certs;

    my $key = read_file($config->{key_file});
    my $rsa_key = pf::ssl::rsa_from_string($key);

    my $data = {
        certificate => pf::ssl::x509_info($x509_cert),
        cas => [ map {pf::ssl::x509_info($_)} @cas ],
        chain_is_valid => $self->tuple_return_to_hash(pf::ssl::verify_chain($x509_cert, \@cas)),
        cert_key_match => $self->tuple_return_to_hash(pf::ssl::validate_cert_key_match($x509_cert, $rsa_key)),
    };

}

sub tuple_return_to_hash {
    my ($self, @values) = @_;
    return {success => $values[0], result => $values[1]};
}


=head2 get

get a filter

=cut

sub get {
    my ($self) = @_;
    return $self->render(json => $self->resource_info, status => 200);
}

=head2 replace

replace a filter

=cut

sub replace {
    my ($self) = @_;
    my $id = $self->stash->{filter_id};
    my ($status, $errors)  = $self->isFilterValid();
    if (is_error($status)) {
        return $self->render_error($status, "Invalid $id file" ,$errors);
    }

    my $body = $self->req->body;
    $body .= "\n" if $body !~ m/\n\z/s;
    pf::util::safe_file_update($self->fileName, $body);
    return $self->render(status => $status, json => {});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

