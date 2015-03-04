package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
use WWW::Curl::Easy;
use Date::Format qw(time2str);
use pf::log;
use pf::config;
use pf::util;
use pf::web qw(i18n ni18n i18n_format render_template);
use pf::web::constants;
use List::MoreUtils qw(uniq any);
use Readonly;
use POSIX;
use URI::Escape::XS qw(uri_escape);
use pf::web;
use pf::Email::Valid;
use lib qw(/usr/local/pf/lib);


BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::TLSProfile - EAPTLS Controller

=head1 DESCRIPTION

Controller for EAPTLS connections.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    my $username = $c->session->{username};
    my $logger  = get_logger;
    my $profile = $c->profile;
    my $request = $c->request;
    my $mac = $c->portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    $provisioner->authorize($mac) if (defined($provisioner));
    $c->stash(
        post_uri            => '/tlsprofile/cert_process',
        destination_url     => 'eap-profile.html',
        certificate_cn      => $request->param_encoded("certificate_cn"),
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_email   => lc( $request->param_encoded("certificate_email")),
        service             => $request->param_encoded("service"),
        profile_list        => $Config{'pki'}{'profile'},
        template            => 'pki.html',
        provisioner         => $provisioner,
        username            => $username,
        );
}
sub build_cert_p12 : Path('/eap-profile.html') : Args(0) {
    my ($self, $c) = @_;
    my $cert_data = $c->stash->{'cert_content'};
    my $certname = $c->stash->{'certificate_cn'} . "p12";
    open FH, "> $cert_dir/$certname" or die $!;
    print FH "$cert_data\n";
}


sub get_cert : Private {
    use bytes;
    my ($self,$c) = @_;
    my $stash = $c->stash;
    my $uri = $Config{'pki'}{'uri'};
    my $username = $Config{'pki'}{'username'};
    my $password = $Config{'pki'}{'password'};
    my $email = $stash->{'certificate_email'};
    my $dot1x_username = $stash->{'certificate_cn'};
    my $organisation = $Config{'pki'}{'organisation'};
    my $state = $Config{'pki'}{'state'};
    my $profile = $Config{'pki'}{'profile'};
    my $country = $Config{'pki'}{'country'};
    my $certpwd = $stash->{'certificate_pwd'};
    my $curl = WWW::Curl::Easy->new; 
    my $request = "username=$username&password=$password&cn=$dot1x_username&mail=$email&organisation=$organisation&st=$state&country=$country&profile=$profile&pwd=$certpwd";
    my $response_body = '';
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);
  
    # Starts the actual request
    my $curl_return_code = $curl->perform;

    if $curl_return_code = 0 {
        $c->stash(
            cert_content    => $response_body,
        );
    }
    elsif $curl_return_code = -1{
        print "There was an issue with the generation of your certificate please contact your IT support."
    }
}
 
sub cert_process : Local {
    my ($self,$c) = @_;
    $c->forward('validateform');
    $c->forward('get_cert');
    $c->forward('cert_p12');
    $c->forward('export_fingerprint');
}

sub validateform : Private {
    my ($self,$c) = @_;
    $c->stash(
        service => $c->request->param('service'),
        my $usern = certificate_cn => $c->request->param('certificate_cn'),
        my $email_addr = certificate_email => $c->request->param('certificate_email'),
        my $userpwd = certificate_pwd => $c->request->param('certificate_pwd'),
    );
    unless (Email::Valid->address($email_addr)){
        print "Sorry, that email address is not valid!";
    }
}

sub export_fingerprint : Local {
    my ($self, $c) = @_;
    my $stash = $c->stash;
    my $cwd = $cert_dir;
    my $pass = $stash->{'certificate_pwd'};
    my $certfile = $stash->{'certificate_cn'};
    my $certp12 = Crypt::OpenSSL::PKCS12->new_from_file("$cwd/$certfile.p12");
    if ($certp12->mac_ok($pass)){
        pf_run("openssl pkcs12 -in $certfile.p12 -passin pass:$pass -out $certfile.pem -passout pass:");
        pf_run("openssl x509 -in $certfile.pem -outform DER -out $certfile.cer");
        my $cmd = "openssl x509 -inform DER -in $certfile.cer -fingerprint";
        my $data = pf_run($cmd);
        $data =~ /.*\/([a-zA-Z0-9.]+)$/;
        $data =~ s/.*SHA1 Fingerprint=//smg; 
        $data =~ s/-----BEGIN CERTIFICATE-----\n.*//smg;
        $data =~ s/\:/\ /smg;
    }
    else {
        print "We could not verifiy the integrity of your certificate, please contact your IT support."
    }
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

__PACKAGE__->meta->make_immutable;

1;
