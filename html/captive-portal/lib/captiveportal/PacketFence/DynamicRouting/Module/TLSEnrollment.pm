package captiveportal::PacketFence::DynamicRouting::Module::TLSEnrollment;

=head1 NAME

captiveportal::DynamicRouting::TLSEnrollment

=head1 DESCRIPTION

TLSEnrollment module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

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
use pf::constants;

has 'pki_provider' => (is => 'rw', isa => 'pf::pki_provider');

has 'pki_provider_id' => (is => 'rw', trigger => \&_build_pki_provider, required => 1);

has 'pki_provider_type' => (is => 'ro', builder => '_build_pki_provider_type', lazy => 1);

=head2 allowed_urls

The allowed URLs

=cut

sub allowed_urls {[
    '/tls-enrollment',
]}

=head2 _build_pki_provider

Builder for the PKI provider

=cut

sub _build_pki_provider {
    my ($self) = @_;
    $self->pki_provider(pf::factory::pki_provider->new($self->{pki_provider_id}));
}

=head2 _build_pki_provider_type

Builder for the PKI provider type

=cut

sub _build_pki_provider_type {
    my ($self) = @_;
    return $pf::factory::pki_provider::MODULES{ref($self->pki_provider)}{'type'};
}

=head2 execute_child

Execute the module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->cert_process();
    }
    else {
        $self->prompt_info();
    }
}

=head2 prompt_info

Prompt for the necessary informations to complete the certificate request

=cut

sub prompt_info {
    my ($self) = @_;
    unless(defined($self->username) && defined($self->app->session->{source})){
        $self->app->error("You are not authenticated.");
        return;
    }

    my $source = $self->app->session->{source};
    my $attributes = $source->search_attributes($self->username);
    my $certificate_email = $attributes ? $attributes->{'email'} : $FALSE;

    my $args = {
        certificate_pwd     => word(4,6),    
        title => "Certificate generation for EAP TLS connection",
    };

    if( $certificate_email ) {
        $self->session->{certificate_email} = $certificate_email;
        $args->{certificate_email} = $certificate_email;
    }

    $self->render("pki_provider/".$self->pki_provider_type.".html",$args);
}

=head2 cert_process

Process order of the TLSProfile controller

=cut

sub cert_process {
    my ($self) = @_;
    my $logger = get_logger;
    unless($self->process_form()) {
        $self->prompt_info();
        return;
    }
    unless($self->prepare_profile()){
        $self->app->error("Problem while preparing the TLS profile");
        return;
    }
    $self->done();
}

=head2 process_form

Process form information inputed by the user

=cut

sub process_form  {
    my ($self) = @_;
    my $logger = get_logger;

    my $mac    = $self->current_mac;
    my $passwd = $self->app->request->param('certificate_pwd');
    my $pki_provider = $self->pki_provider;

    if(!defined $passwd || $passwd eq '') {
        $self->app->flash->{error} = "No Password given";
        return $FALSE;
    }

    my $certificate_email;
    if ( $self->session->{certificate_email} ){
        $certificate_email = $self->session->{certificate_email};
    }
    elsif ( defined($self->app->request->param('certificate_email')) && $self->app->request->param('certificate_email') ne '' ){
        $certificate_email = $self->app->request->param('certificate_email');
    }
    else {
        $self->app->flash->{error} = "No e-mail given";
        return $FALSE;
    }

    my $node_info = $self->node_info();
    my $certificate_cn = $pki_provider->user_cn($node_info);
    my $user_cache = $self->app->user_cache;
    my $pki_session = {
        service           => $self->app->request->param('service'),
        certificate_cn    => $certificate_cn,
        certificate_email => $certificate_email,
        certificate_pwd   => $passwd,
    };
    $user_cache->set("pki_session" => $pki_session);
    
    return $TRUE;
}

=head2 get_bundle

Use PkiProvider{get_bundle} method to send the request in order to generate the certificate

=cut

sub get_bundle {
    my ($self) = @_;
    my $pki_provider = $self->pki_provider;
    my $mac           = $self->current_mac;
    my $user_cache = $self->app->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});
    my $cert_content = $pki_provider->get_bundle({ certificate_email => $pki_session->{certificate_email}, certificate_cn => $pki_session->{certificate_cn}, certificate_pwd => $pki_session->{certificate_pwd} });
    get_logger->debug(sub { "cert_content from pki service $cert_content" });

    unless(defined($cert_content)){
        $self->app->error("Your certificate could not be aquired from the certificate server. Try again later or contact your network administrator.");
        return $FALSE;
    }

    $self->session->{cert_content} = $cert_content;
    return $TRUE;
}

=head2 prepare_profile

Prepares all the data necessary for the profile rendering

=cut

sub prepare_profile {
    my ($self) = @_;
    my $logger = get_logger;
    my $mac    = $self->current_mac;
    my $user_cache = $self->app->user_cache;
    my $pki_session = $user_cache->compute("pki_session", sub {});

    my $ca_content = $self->pki_provider->raw_ca_cert_string();
    my $server_content = $self->pki_provider->raw_server_cert_string();
    my $server_cn = $self->pki_provider->server_cn();
    my $ca_cn = $self->pki_provider->ca_cn();

    return $FALSE unless($self->get_bundle());
    my $b64_cert = encode_base64($self->session->{cert_content});

    @$pki_session{qw(ca_cn server_cn ca_content server_content b64_cert)} = (
        $ca_cn,
        $server_cn,
        $ca_content,
        $server_content,
        $b64_cert,
    );
    $user_cache->set("pki_session" => $pki_session);
    return $TRUE;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

