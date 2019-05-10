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
use pf::ssl::lets_encrypt;
use pf::util;
use File::Slurp qw(read_file);
use pf::error qw(is_error);
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::log;
use pf::constants;

my $CERT_DELIMITER = "-----END CERTIFICATE-----";


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

=head2 resource_config

Get the configuration associated to a resource

=cut

sub resource_config {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    return pf::ssl::certs_map()->{$certificate_id};
}

=head2 read_from_files

Read the certificate data from files and put it in a hash that matches the expected input format when using PUT

=cut

sub read_from_files {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    my $config = $self->resource_config($certificate_id);
    
    my $certs = read_file($config->{cert_file});
    my @certs = map { $_ . $CERT_DELIMITER} split($CERT_DELIMITER, $certs);

    # The last element should be discarded due to the way the certs are extracted (split) above
    pop @certs;

    my $ca = defined($config->{ca_file}) ? read_file($config->{ca_file}) : undef;

    # The server certificate is the first of the whole chain
    my $cert = shift @certs;
    
    my $key = read_file($config->{key_file});

    my $files_data = {
        private_key => $key,
        certificate => $cert,
        intermediate_cas => \@certs,
        ca => $ca,
    };

    delete $files_data->{ca} unless(defined($files_data->{ca}));

    return $files_data;
}

=head2 objects_from_files

Read the certificates from the files and instantiate the Crypt::OpenSSL::* objects

=cut

sub objects_from_files {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    
    return $self->objects_from_payload($self->read_from_files($certificate_id));
}

=head2 get

Get a certificate resource

=cut

sub get {
    my ($self) = @_;
    my $files_data = $self->read_from_files();
    $files_data->{lets_encrypt} = isenabled(pf::ssl::lets_encrypt::resource_state($self->stash->{certificate_id})) ? $self->json_true : $self->json_false;
    $self->render(json => $files_data, status => 200);
}

=head2 resource_info
    
Get a resource information including certificate information, chain validation and cert/key match

=cut

sub resource_info {
    my ($self, $certificate_id) = @_;
    $certificate_id //= $self->stash->{certificate_id};
    my $config = $self->resource_config($certificate_id);

    my ($x509_cert, $x509_intermediate_cas, $x509_cas, $x509_ca, $rsa_key) = $self->objects_from_files($certificate_id);
    unless(defined($x509_cert)) {
        return;
    }

    my $data = {
        certificate => pf::ssl::x509_info($x509_cert),
        intermediate_cas => [ map {pf::ssl::x509_info($_)} @$x509_intermediate_cas ],
        chain_is_valid => $self->tuple_return_to_hash(pf::ssl::verify_chain($x509_cert, $x509_cas)),
        cert_key_match => $self->tuple_return_to_hash(pf::ssl::validate_cert_key_match($x509_cert, $rsa_key)),
        lets_encrypt => isenabled(pf::ssl::lets_encrypt::resource_state($self->stash->{certificate_id})) ? $self->json_true : $self->json_false,
    };
    if($x509_ca) {
        $data->{ca} = pf::ssl::x509_info($x509_ca);
    }

    return $data;
}

=head2 tuple_return_to_hash

Transform a tuple return value (as seen in pf::ssl::*) into a hash for adding it to the HTTP response

=cut

sub tuple_return_to_hash {
    my ($self, @values) = @_;
    return {success => $values[0], result => $values[1]};
}


=head2 get

get a certificate bundle

=cut

sub info {
    my ($self) = @_;
    if(my $info = $self->resource_info) {
        return $self->render(json => $info, status => 200);
    }
}

=head2 objects_from_payload

Instantiate the Crypt::OpenSSL::* objects from a hash payload

=cut

sub objects_from_payload {
    my ($self, $data) = @_;
    
    my $cert;
    my @intermediate_cas;
    my @cas;
    my $ca;
    my $key;
    eval {
        $cert = pf::ssl::x509_from_string($data->{certificate}) or die "Failed to parse server certificate\n";
        $key = pf::ssl::rsa_from_string($data->{private_key}) or die "Failed to parse private key\n";
        
        if(exists($data->{intermediate_cas})) {
            @intermediate_cas = map { pf::ssl::x509_from_string($_) or die "Failed to parse one of the certificate CAs\n" } @{$data->{intermediate_cas}};
            @cas = @intermediate_cas;
        }
        else {
            my ($res, $certs) = pf::ssl::fetch_all_intermediates($cert);
            if($res) {
                @intermediate_cas = @$certs;
                @cas = @intermediate_cas;
            }
            else {
                my $msg = "Unable to fetch intermediate certificates ($certs). You will have to upload your intermediate chain manually in x509 (Apache) format.";
                $self->log->error($msg);
                return $self->render_error("422", $msg);
            }
        }

        if($data->{ca}) {
            $ca = pf::ssl::x509_from_string($data->{ca}) or die "Failed to parse CA certificate\n";
            push @cas, $ca;
        }
    };
    if($@) {
        my $msg = $@;
        chomp($msg);
        $self->log->error($msg);
        $self->render_error("500", $msg);
        return (undef);
    }

    return ($cert, \@intermediate_cas, \@cas, $ca, $key);
}

=head2 replace

replace a certificate bundle (key, certs, etc)

=cut

sub replace {
    my ($self) = @_;
    my $data = $self->parse_json;
    my $params = $self->req->query_params->to_hash;
    
    # Explicitely disable Let's Encrypt if manually managing certs
    pf::ssl::lets_encrypt::resource_state($self->stash->{certificate_id}, "disabled");

    my ($cert, $intermediate_cas, $cas, $ca, $key) = $self->objects_from_payload($data);
    unless(defined($cert)) {
        return;
    }

    if(!defined($params->{check_chain}) || isenabled($params->{check_chain})) {
        my ($chain_res, $chain_msg) = pf::ssl::verify_chain($cert, $cas);
        unless($chain_res) {
            my $msg = "Failed verifying chain: $chain_msg.";
            if(exists($data->{intermediate_cas})) {
                $msg .= " Ensure the intermediates certificate file you provided contains all the intermediate certificate authorities in x509 (Apache) format.";
            }
            else {
                $msg .= " Unable to fetch all the intermediates through the information contained in the certificate. You will have to upload the intermediate chain manually in x509 (Apache) format.";
            }

            $self->log->error($msg);
            return $self->render_error("422", $msg);
        }
    }

    my ($key_match_res, $key_match_msg) = pf::ssl::validate_cert_key_match($cert, $key);
    unless($key_match_res) {
        my $msg = "Certificate and private key do not match";
        $self->log->error($msg);
        return $self->render_error("422", $msg);
    }

    my %to_install = (
        cert_file => join("\n", map { $_->as_string() } ($cert, @$intermediate_cas)),
        key_file => $key->get_private_key_string(),
        ca_file => ($ca ? $ca->as_string() : ""),
    );
    $to_install{bundle_file} = join("\n", $to_install{cert_file}, $to_install{key_file});

    my @errors = pf::ssl::install_to_file($self->stash->{certificate_id}, %to_install);
    
    if(scalar(@errors) > 0) {
        $self->render_error(422, join(", ", @errors));
    }
    else {
        $self->render(json => {}, status => 200)
    }
}

=head2 generate_csr

Generate a CSR request for a certificate resource

=cut

sub generate_csr {
    my ($self) = @_;
    my $data = $self->parse_json();
    my $config = $self->resource_config();
    my $key_str = read_file($config->{key_file});
    my $rsa = pf::ssl::rsa_from_string($key_str);
    my ($res, $csr) = pf::ssl::generate_csr($rsa, $data);

    if($res) {
        $self->render(json => {csr => $csr->get_pem_req()}, status => 200);
    }
    else {
        $self->render_error(422, $csr);
    }
}

=head2 lets_encrypt_test

Test public connectivity (accessible through the Internet) of a specific domain and ensure that the acme-challenge directory is available

=cut

sub lets_encrypt_test {
    my ($self) = @_;

    my $params = $self->req->query_params->to_hash;

    if(my $domain = $params->{domain}) {
        my ($res, $msg) = pf::ssl::lets_encrypt::test_domain($domain);
        $res = $res ? $TRUE : $FALSE;
        $self->render(json => $self->tuple_return_to_hash($res, $msg), status => $res ? 200 : 422);
    }
    else {
        $self->render_error(422, "Missing domain parameter");
    }

}

=head2 lets_encrypt_replace

Handle a PUT call to enable Let's Encrypt for a certificate resource

=cut

sub lets_encrypt_replace {
    my ($self) = @_;

    my $data = $self->parse_json();
    my $config = $self->resource_config();

    get_logger->info("Performing Let's Encrypt configuration for domain $data->{common_name} using key $config->{key_file}");

    # Explicitely enable Let's Encrypt if using this API call
    pf::ssl::lets_encrypt::resource_state($self->stash->{certificate_id}, "enabled");

    my ($result, $bundle) = pf::ssl::lets_encrypt::obtain_bundle($config->{key_file}, $data->{common_name});

    unless($result) {
        return $self->render_error(422, $bundle);
    }

    my $cert = $bundle->{certificate};
    my $intermediate_cas = $bundle->{intermediate_cas};
    my $key_str = read_file($config->{key_file});

    my %to_install = (
        cert_file => join("\n", map { $_->as_string() } ($cert, @$intermediate_cas)),
        key_file => $key_str,
    );
    $to_install{bundle_file} = join("\n", $to_install{cert_file}, $to_install{key_file});

    my @errors = pf::ssl::install_to_file($self->stash->{certificate_id}, %to_install);
    
    if(scalar(@errors) > 0) {
        $self->render_error(422, join(", ", @errors));
    }
    else {
        $self->render(json => {}, status => 200)
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

