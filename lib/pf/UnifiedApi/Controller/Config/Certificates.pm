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
use pf::util;
use File::Slurp qw(read_file);
use pf::error qw(is_error);
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::file_paths qw(
    $server_cert
    $server_key
    $server_pem
    $radius_server_cert
    $radius_ca_cert
    $radius_server_key
);

my $CERT_DELIMITER = "-----END CERTIFICATE-----";

my %CERTS_MAP = (
    http => {
        cert_file => $server_cert,
        key_file => $server_key,
        bundle_file => $server_pem,
    },
    radius => {
        cert_file => $radius_server_cert,
        ca_file => $radius_ca_cert,
        key_file => $radius_server_key,
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

    # The server certificate is the first of the whole chain
    my $cert = shift @certs;
    
    my $key = read_file($config->{key_file});

    my $x509_cert;
    my @cas;
    my $rsa_key;
    eval {
        $x509_cert = pf::ssl::x509_from_string($cert) or die "Failed to parse certificate\n";
        @cas = map { pf::ssl::x509_from_string($_) or die "Failed to parse one of the certificate CAs\n" } @certs;
        $rsa_key = pf::ssl::rsa_from_string($key) or die "Failed to parse private key\n";
    };
    if($@) {
        my $msg = $@;
        chomp($msg);
        $self->log->error($msg);
        $self->render_error("500", $msg);
        return undef;
    }

    my $data = {
        certificate => pf::ssl::x509_info($x509_cert),
        cas => [ map {pf::ssl::x509_info($_)} @cas ],
        chain_is_valid => $self->tuple_return_to_hash(pf::ssl::verify_chain($x509_cert, \@cas)),
        cert_key_match => $self->tuple_return_to_hash(pf::ssl::validate_cert_key_match($x509_cert, $rsa_key)),
    };

    return $data;
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
    if(my $info = $self->resource_info) {
        return $self->render(json => $info, status => 200);
    }
}

sub objects_from_put_payload {
    my ($self, $data) = @_;
    
    my $cert;
    my @intermediate_cas;
    my @cas;
    my $ca;
    my $key;
    eval {
        $cert = pf::ssl::x509_from_string($data->{certificate}) or die "Failed to parse server certificate\n";
        $key = pf::ssl::rsa_from_string($data->{private_key}) or die "Failed to parse private key\n";
        
        if(exists($data->{intermediates})) {
            @intermediate_cas = map { pf::ssl::x509_from_string($_) or die "Failed to parse one of the certificate CAs\n" } @{$data->{intermediates}};
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

replace a filter

=cut

sub replace {
    my ($self) = @_;
    my $data = $self->parse_json;
    my $params = $self->req->query_params->to_hash;

    my ($cert, $intermediate_cas, $cas, $ca, $key) = $self->objects_from_put_payload($data);
    unless(defined($cert)) {
        return;
    }

    if(!defined($params->{check_chain}) || isenabled($params->{check_chain})) {
        my ($chain_res, $chain_msg) = pf::ssl::verify_chain($cert, $cas);
        unless($chain_res) {
            my $msg = "Failed verifying chain: $chain_msg.";
            if(exists($data->{intermediates})) {
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
        ca_file => $ca,
    );
    $to_install{bundle_file} = join("\n", $to_install{cert_file}, $to_install{key_file});

    my @errors = $self->install_to_file(%to_install);
    
    if(scalar(@errors) > 0) {
        $self->render_error(422, join(", ", @errors));
    }
    else {
        $self->render(json => {}, status => 200)
    }
}

sub install_to_file {
    my ($self, %to_install) = @_;
    
    my $config = $self->resource_config();

    my @errors;
    while(my ($k, $content) = each(%to_install)) {
        my $file = $config->{$k};
        next unless(defined($file));

        my ($res,$msg) = pf::ssl::install_file($file, $content);
        if($res) {
            $self->log->info("Installed file $file successfully");
        }
        else {
            my $msg = "Failed installing file $file: $msg";
            $self->log->error($msg);
            push @errors, $msg;
        }
    }

    return @errors;
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

