package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
use WWW::Curl::Easy;
use pf::log;
use pf::config;
use pf::util;
use pf::node;
use pf::web::constants;
use List::MoreUtils qw(uniq any);
use pf::authentication;
use HTML::Entities;
use MIME::Base64;
use File::Slurp;
use File::Basename;
use pf::web;
use Crypt::OpenSSL::X509;


BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'tlsprofile', );

=head1 NAME

captiveportal::PacketFence::Controller::TLSProfile - EAPTLS Controller

=head1 DESCRIPTION

Controller for EAPTLS connections.

=head1 METHODS

=cut

=head2 index

Collect information about the user and the certificate to generate

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    my $username = $c->session->{username};
    my $logger  = get_logger;
    my $profile = $c->profile;
    my $request = $c->request;
    my $mac = $c->portalSession->clientMac;
    my $node_info = node_view($mac);
    my $pid = $node_info->{'pid'};
    my $provisioner = $c->profile->findProvisioner($mac);
    my $certificate_cn = $mac;
    $certificate_cn =~ s/:/-/g;
    $c->stash(
        post_uri            => '/tlsprofile/cert_process',
        certificate_cn      => $certificate_cn,
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_pwd_check     => $request->param_encoded("certificate_pwd_check"),
        certificate_email   => lc( $request->param_encoded("certificate_email") || $request->param_encoded("email")),
        template            => 'pki.html',
        provisioner         => $provisioner,
        username            => $username,
        mac                 => $mac,
        pid                 => $pid,
    );
}

=head2 build_cert_p12

Build a certificate file in p12 with the answer of the pki

=cut

sub build_cert_p12 : Path : Args(0) {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $cert_data = $c->stash->{'cert_content'};
    my $cert = $c->stash->{'certificate_cn'} . ".p12";
    my $certname = "$cert_dir/$cert";
    $c->session( certificate_cn => $cert );
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $node_info     = node_view($mac);
    my $pid           = $node_info->{'pid'};
    my $fh;
    if ( open ($fh, '>', $certname) ) {
        $logger->debug("Certificate for user \"$pid\" successfully created.");
        print $fh "$cert_data\n";
        close $fh;
    }
    else {
        $logger->error("The certificate file could not be saved for username \"$pid\"");
        $self->showError($c,"An error has occured while trying to save your certificate, please contact your local support staff");
    }
}

=head2 get_cert

Use PkiProvider{get_cert} method to send the request in order to generate the certificate

=cut

sub get_cert : Private {
    my ($self, $c) = @_;
    my ($provisioner,$pki_provider);
    my $portalSession = $c->portalSession;
    my $stash = $c->stash;
    my $mac           = $portalSession->clientMac;
    $provisioner   = $c->profile->findProvisioner($mac);
    unless ($provisioner && ($pki_provider = $provisioner->getPkiProvider())) {
        $c->log->error("No provisioner or pki_provider was found!");
        $self->showError($c,"An error has occured while trying to save your certificate, please contact your local support staff");
    }
    my $cert_content = $pki_provider->get_cert({ certificate_email => $stash->{certificate_email}, certificate_cn => $stash->{certificate_cn}, certificate_pwd => $stash->{certificate_pwd} });
    $c->log->debug(sub { "cert_content from pki service $cert_content" });
    $c->stash(cert_content => $cert_content);
}

=head2 cert_process

Process order of the TLSProfile controller

=cut

sub cert_process : Local {
    my ($self,$c) = @_;
    my $logger = $c->log;
    $c->stash(info => $c->session->{info});
    $c->forward('validate_form');
    $c->forward('get_cert');
    $c->forward('build_cert_p12');
    $c->forward('b64_cert');
    $c->forward('export_fingerprint');
    $c->forward( 'Authenticate' => 'checkIfProvisionIsNeeded' );
    $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}{pid}, %{$c->stash->{info}}]);
    $c->forward( 'CaptivePortal' => 'endPortalSession' );
}

=head2 validate_form

Validate informations input by the user

=cut

sub validate_form : Private {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    my $passwd1 = $c->request->param('certificate_pwd');
    my $passwd2 = $c->request->param('certificate_pwd_check');
    if(!defined $passwd1 || $passwd1 eq '' || !defined $passwd2 || $passwd2 eq '') {
        $c->stash(txt_validation_error => 'No Password given');
        $c->detach('index');
    }
    if($passwd1 ne $passwd2) {
        $c->stash(txt_validation_error => 'Passwords do not match');
        $c->detach('index');
    }
    my $certificate_email = $c->request->param('certificate_email');
    my $certificate_pwd = $c->request->param('certificate_pwd');
    if(!defined $certificate_email || $certificate_email eq '') {
        $c->stash(txt_validation_error => 'No email provided');
        $c->detach('index');
    }
    my $certificate_cn = $mac;
    $certificate_cn =~ s/:/-/g;
    my $user_cache = $c->user_cache;
    my $pki_session = {
        service           => $c->request->param('service'),
        certificate_cn    => $certificate_cn,
        certificate_email => $certificate_email,
        certificate_pwd   => $passwd1,
    };
    $user_cache->set("pki_session" => $pki_session);
    $c->stash($pki_session);
}

=head2 b64_cert

Encode user certificate in b64

=cut

sub b64_cert : Local {
    my ($self,$c) = @_;
    my $session = $c->session;
    my $stash = $c->stash;
    my $cwd = $cert_dir;
    my $certfile = $stash->{'certificate_cn'};
    my $certp12 = "$cwd/$certfile.p12";
    my $certstr = read_file($certp12);
    my $b64 = encode_base64($certstr);
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    $pki_session->{b64_cert} = $b64;
    $user_cache->set("pki_session" => $pki_session);
    $c->session(
        b64_cert => $b64,
    );
}

=head2 export_fingerprint

Get the fingerprint of the CA, to allow the trust under windows

=cut

sub export_fingerprint : Local {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    my $stash = $c->stash;
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    
    my $svrpath = $radius_svr_cert;
    my $cacert = Crypt::OpenSSL::X509->new_from_string($provisioner->ca_cert);
    my $castr = $cacert->as_string();
    my $cafinger = $cacert->fingerprint_sha1();
    $c->session( fingerprint => $cafinger );
    my $svrcert = Crypt::OpenSSL::X509->new_from_file($svrpath);
    my $svrstr = $cacert->as_string();
    my $cafile = $cacert->subject;
    my $svrfile = $svrcert->subject;
    $c->session( cacn => $cafile );
    $c->session( svrcn => $svrfile );
    $castr =~ s/-----END CERTIFICATE-----\n.*//smg;
    $castr=~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    $c->session( cadata => $castr );
    $svrstr =~ s/-----END CERTIFICATE-----\n.*//smg;
    $svrstr =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    $c->session( svrdata => $svrstr );
    @$pki_session{qw(cacn svrcn cadata svrdata fingerprint)} = (
        $cafile,
        $svrfile,
        $castr,
        $svrstr,
        $cafinger,
    );
    $user_cache->set("pki_session" => $pki_session);
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
