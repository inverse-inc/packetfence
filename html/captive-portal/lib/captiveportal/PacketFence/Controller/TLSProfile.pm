package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
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
    $c->stash(
        post_uri            => '/tlsprofile/cert_process',
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
    my $cert_content  = $c->stash->{'cert_content'};
    my $cn            = $c->stash->{'certificate_cn'};
    my $cert_path     = "$users_cert_dir/$cn.p12";
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $node_info     = node_view($mac);
    my $pid           = $node_info->{'pid'};
    my $fh;
    if ( open ($fh, '>', $cert_path) ) {
        print $fh $cert_content;
        close $fh;
        $logger->info("Certificate for user \"$pid\" successfully created under path $cert_path.");
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
    $c->forward('prepare_profile');
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
    my $passwd = $c->request->param('certificate_pwd');
    my $passwd_confirm = $c->request->param('certificate_pwd_check');
    if(!defined $passwd || $passwd eq '' || !defined $passwd_confirm || $passwd_confirm eq '') {
        $c->stash(txt_validation_error => 'No Password given');
        $c->detach('index');
    }
    if($passwd ne $passwd_confirm) {
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
        certificate_pwd   => $passwd,
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
    my $cn = $stash->{'certificate_cn'};
    my $cert_path = "$users_cert_dir/$cn.p12";
    my $cert_content = read_file($cert_path);
    my $b64_cert = encode_base64($cert_content);
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    $pki_session->{b64_cert} = $b64_cert;
    $user_cache->set("pki_session" => $pki_session);
}


# MOVE ME TO PKI PROVIDER
sub getServerCn() {
    my ($self, $c) = @_;
    # CHANGE ME - I'M UGLY:(
    my $server_cert_path = '/usr/local/pf/conf/ssl/server.crt';
    my $server_cert = Crypt::OpenSSL::X509->new_from_file($server_cert_path);
    if($server_cert->subject =~ /CN=(.*?),/){
        return $1;
    }
    else {
        $c->log->error("Cannot find CN of server certificate at $server_cert_path");
    }
}


# MOVE ME TO PKI PROVIDER
sub getCaCn() {
    my ($self, $c) = @_;
    # CHANGE ME - I'M UGLY:(
    my $ca_cert_path = '/usr/local/pf/conf/ssl/ca.crt';
    my $ca_cert = Crypt::OpenSSL::X509->new_from_file($ca_cert_path);
    print $ca_cert->subject."\n";
    if($ca_cert->subject =~ /CN=(.*?),/g){
        return $1;
    }
    else {
        $c->log->error("Cannot find CN of server certificate at $ca_cert_path");
    }
   
}

=head2 prepare_profile

Prepares all the data necessary for the profile rendering

=cut

sub prepare_profile : Local {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    my $stash = $c->stash;
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    
    my $ca_content = $provisioner->raw_ca_cert_string();
    $ca_content =~ s/-----END CERTIFICATE-----\n.*//smg;
    $ca_content =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;

    my $server_cn = $provisioner->getPkiProvider()->get_server_cn();
    my $ca_cn = $provisioner->getPkiProvider()->get_server_cn();
    @$pki_session{qw(ca_cn server_cn ca_content)} = (
        $ca_cn,
        $server_cn,
        $ca_content,
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
