package pf::pki_provider::dogtag;

=head1 NAME

pf::pki_provider::dogtag

=cut

=head1 DESCRIPTION

pf::pki_provider::scep

=cut

use strict;
use warnings;
use Moo;
use WWW::Curl::Easy;
use pf::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use File::Slurp qw(read_file);
use IPC::Cmd qw[can_run run ];
use File::Tempdir;
use File::Temp qw/ tempfile /;


extends 'pf::pki_provider';

use pf::log;

=head2 url

The URL of the SCEP PKI service

=cut

has url => ( is => 'rw' );

=head2 crlURI

The URI of the Certificate Revocation List

=cut

has crlURI => ( is => 'ro' );

=head2 challenge_password

The password to connect to the SCEP PKI service

=cut

has challenge_password => ( is => 'rw' );

=head2 custom_subject

A custom subject to override the built subject from attributes

=cut

has custom_subject => ( is => 'rw' );

=head2 client_template

A template to generate an openssl configuration file for certificate signing requests

=cut
my $template = <<'EOF';
[ req ]
prompt          = no
distinguished_name  = client
default_bits        = 2048
input_password      = ''
output_password     = ''
attributes          = req_attributes
req_extensions      = req_extensions

[ req_attributes ]
challengePassword   = [% challenge_password %]

[ req_extensions ]
extendedKeyUsage = 1.3.6.1.5.5.7.3.2
crlDistributionPoints = URI:[% crlURI %]
subjectAltName =   email:[% email %]

[client]
countryName         = [% country %]
stateOrProvinceName = [% state %]
localityName        = [% locality %]
organizationName    = [% organisation %]
emailAddress        = [% email %] 
commonName          = [% email %]
EOF


has client_template => ( is => 'ro', default => $template);

=head2 client_conf_file 

A configuration file generated from the the client_template for openssl request generation

=cut

has client_conf_file => ( is => 'rw');


=head2 module_description

=cut

sub module_description { 'Fedora Dogtag PKI' }

=head2 get_bundle

Get the certificate from the SCEP PKI service
sscep enroll -c AD2008-0 -e AD2008-1 -k local.key -r local.csr -l cert.crt -S sha1 -u 'http://dogtag2.inverse.local:8080/ca/cgi-bin/pkiclient.exe' -d

=cut

sub get_bundle {
    my ($self,$args) = @_;
    my $logger = get_logger();
    my $temp_dir = File::Tempdir->new;
    my $path = $temp_dir->name;
    my $ca = $self->get_ca($path, $args);
    my $request  = $self->make_request($path, $args);
    my $cert_path = "$path/cert";
    system("sscep", "enroll", "-c", $ca, "-k",$request->{key}, '-r', $request->{csr}, "-u",$self->url, '-S', 'sha1', '-l', $cert_path);
    my $cert = eval {
        read_file ($cert_path)
    };
    return Crypt::OpenSSL::PKCS12->create_as_string($cert, $request->{key}, $args->{certificate_pwd});
}

=head2 get_ca

sscep getca  -u http://dogtag2.inverse.local:8080/ca/cgi-bin/pkiclient.exe -c tempdir/ca

=cut

sub get_ca {
    my ($self,$temp_dir, $args) = @_;
    my $ca_file = "${temp_dir}/ca.pem";
    system("sscep", "getca", "-u", $self->url, "-c", $ca_file);
    return "$ca_file";
}

=head2 make_request

=cut

sub make_request {
    my ($self, $tempdir, $args) = @_;
    my $logger = get_logger();
    my $key_path = "$tempdir/key";
    my $csr_path = "$tempdir/csr";
    my $config_path = "$tempdir/client.conf";
    
    my $tt = Template->new();
    my $client_conf;
    my %vars = (
        challenge_password     => $self->challenge_password,
        crlURI       => $self->crlURI,
        country      => ( $self->country // '' ),
        state        => ( $self->state // '' ),
        locality     => ( $self->locality // '' ),
        organisation => ( $self->organization // '' ),
        orgUnit      => ( $self->organizational_unit // '' ),
        email        => $args->{'certificate_cn'},
    );
    $tt->process( \$self->client_template, \%vars, \$client_conf);

    open (my $fh, ">", "$config_path") 
        or $logger->error("Error writing openssl configuration: " . $?);
    print $fh $client_conf;
    close $fh;

    my $cmd = qq[ openssl req -new -out $csr_path -nodes -keyout $key_path -config $config_path ];
    my $buffer;
    scalar run ( 
        command => $cmd,
        verbose => 1,
        buffer  => \$buffer,
        timeout => 5 );

    unlink $config_path;

    my $request_data = {
        key => $key_path,
        csr => $csr_path,
    };
    return $request_data;
}


=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    my ($self, $cn) = @_;
    my $logger = get_logger();
    $logger->warn("Calling a revoke on a PKI provider that does not support it");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
