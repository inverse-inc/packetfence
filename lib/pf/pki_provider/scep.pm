package pf::pki_provider::scep;

=head1 NAME

pf::pki_provider::scep

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
use File::Tempdir;
use File::Slurp qw(read_file);
use Crypt::OpenSSL::PKCS10;

extends 'pf::pki_provider';

use pf::log;

=head2 host

The host of the scep pki service

=cut

has host => ( is => 'rw', default => "127.0.0.1" );

=head2 port

The port of the scep pki service

=cut

has port => ( is => 'rw', default => 80 );

=head2 proto

The proto of the scep pki service

=cut

has proto => ( is => 'rw', default => "http" );

=head2 username

The username to connect to the scep pki service

=cut

has username => ( is => 'rw' );

=head2 url

The url of the sscep service

=cut

has url => ( is => 'rw' );

=head2 password

The password to connect to the scep pki service

=cut

has password => ( is => 'rw' );

=head2 profile

The profile to use for the scep pki service

=cut

has profile => ( is => 'rw' );

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

=head2 get_cert

Get the certificate from the scep pki service
sscep enroll -c AD2008-0 -e AD2008-1 -k local.key -r local.csr -l cert.crt -S sha1 -u 'http://10.0.0.16/certsrv/mscep/' -d

=cut

sub get_cert {
    my ($self,$args) = @_;
    my $logger = get_logger();
    my $temp_dir = File::Tempdir->new;
    my $path = $temp_dir->name;
    my $ca = $self->get_ca($path, $args);
    my $request  = $self->make_request($path, $args);
    my $cert_path = "$path/cert";
    system("sscep", "enroll", "-c", $ca->[0],'-e', $ca->[1],"-k",$request->{key}, '-r', $request->{csr}, "-u",$self->url, '-S', 'sha1', '-l', $cert_path);
    my $cert = read_file ($cert_path);
    return $cert;
}

=head2 get_ca

sscep getca  -u http://10.0.0.16/certsrv/mscep/ -c tempdir/ca-prefix

=cut

sub get_ca {
    my ($self,$temp_dir, $args) = @_;
    my $ca_base = "${temp_dir}/ca";
    system("sscep", "getca", "-u", $self->url, "-c", $ca_base);
    return ["$ca_base-0", "$ca_base-1", "$ca_base-2"];

}

=head2 make_request

=cut

sub make_request {
    my ($self, $tempdir, $args) = @_;
    my $key_path = "$tempdir/key";
    my $csr_path = "$tempdir/csr";
    my $request_data = {
        key => $key_path,
        csr => $csr_path,
    };
    my $req = Crypt::OpenSSL::PKCS10->new(2048);;
    my $subject = $self->subject_string($args);
    $req->set_subject($subject);
    $req->add_ext(Crypt::OpenSSL::PKCS10::NID_subject_alt_name,"email:" . $args->{certificate_email});
    $req->add_ext_final();
    $req->sign();
    $req->write_pem_pk($key_path);
    $req->write_pem_req($csr_path);
    return $request_data;
}


=head2 subject_string

TODO: documention
	echo "C=$COUNTRY" >> $CONFIG
fi
if [ "$STATE" ]; then
	echo "ST=$STATE" >> $CONFIG
fi
if [ "$LOCALITY" ]; then
	echo "L=$LOCALITY" >> $CONFIG
fi
if [ "$ORGANIZATION" ]; then
	echo "O=$ORGANIZATION" >> $CONFIG
fi
if [ "$ORGANIZATIONAL_UNIT" ]; then
	echo "OU=$ORGANIZATIONAL_UNIT" >> $CONFIG
fi
if [ ! "$UNSTRUCTURED_NAME" ]; then
	echo "CN=$PARAMETER" >> $CONFIG

=cut

sub subject_string {
    my ($self, $args) = @_;
    my $subject = '';
    $subject .= "/C=" . $self->country;
    $subject .= "/ST=" . $self->state;
    $subject .= "/L=" . $self->locality;
    $subject .= "/O=" . $self->organization;
    $subject .= "/OU=" . $self->organizational_unit;
    $subject .= "/CN=" . $args->{'certificate_cn'};
    return $subject;
}


=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    my ($self, $cn) = @_;
    my $logger = get_logger();
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
