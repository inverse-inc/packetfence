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
use pf::password;
use Crypt::GeneratePassword qw(word);


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

    unless(defined($c->session->{username})){
        $c->log->warn("$mac tried to access the TLS profile page without being authenticated.");
        $c->response->redirect('/authenticate');
    }

    if ( $c->request->method eq 'POST' ) {
        $c->log->info("Processing TLSProfile post");
        $c->detach('cert_process');
    }

    my $provisioner = $c->profile->findProvisioner($mac);
    $c->stash(
        certificate_pwd     => word(4,6),
        post_uri            => '/tlsprofile',
        template            => 'pki.html',
    );
    $c->detach();
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

sub cert_process : Private {
    my ($self,$c) = @_;
    my $logger = $c->log;
    $c->stash(info => $c->session->{info});
    $c->forward('process_form');
    $c->forward('prepare_profile');
    $c->log->info("Finished preparing the TLS profile. Registering the node.");
    $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}{pid}, %{$c->stash->{info}}]);
    $c->forward( 'CaptivePortal' => 'endPortalSession' );
}

=head2 validate_form

Validate informations input by the user

=cut

sub process_form : Private {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    my $passwd = $c->request->param('certificate_pwd');
    if(!defined $passwd || $passwd eq '') {
        $c->stash(txt_validation_error => 'No Password given');
        $c->detach('index');
    }

    my $source_id = $c->session->{source_id};
    my $source = getAuthenticationSource($source_id);
    my $certificate_email = $source->search_attributes($c->session->{username})->get_value('mail');

    my $provisioner   = $c->profile->findProvisioner($mac);
    my $pki_provider = $provisioner->getPkiProvider();

    my $certificate_cn = $pki_provider->user_cn($mac);
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

=head2 prepare_profile

Prepares all the data necessary for the profile rendering

=cut

sub prepare_profile : Private {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    my $stash = $c->stash;
    my $user_cache = $c->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    
    my $ca_content = $provisioner->getPkiProvider()->raw_ca_cert_string();
    my $server_cn = $provisioner->getPkiProvider()->server_cn();
    my $ca_cn = $provisioner->getPkiProvider()->ca_cn();

    $c->forward('get_cert');
    my $b64_cert = encode_base64($stash->{cert_content});

    @$pki_session{qw(ca_cn server_cn ca_content b64_cert)} = (
        $ca_cn,
        $server_cn,
        $ca_content,
        $b64_cert,
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
