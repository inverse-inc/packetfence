package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
use WWW::Curl::Easy;
use Date::Format qw(time2str);
use pf::log;
use pf::config;
use pf::temporary_password 1.11;
use pf::util;
use pf::web qw(i18n ni18n i18n_format render_template);
use pf::web::constants;
use pf::web::util;
use pf::web::guest;
use pf::activation;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::authentication;
use List::MoreUtils qw(uniq any);
use Readonly;
use POSIX;
use URI::Escape::XS qw(uri_escape);
use pf::web;
use lib qw(/usr/local/pf/lib);


BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

#sub index : Path : Args(0) {
#    my ( $self, $c ) = @_;
#    my $username = $c->session->{username} || '';
#    my $mac = $c->portalSession->clientMac;
#    my $provisioner = $c->profile->findProvisioner($mac);
#    $provisioner->authorize($mac) if (defined($provisioner));
#    $c->stash(
#        template     => 'eap-profile.html',
#        current_view => 'MobileConfig',
#        provisioner  => $provisioner,
#        username     => $username,
#        );
#}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $username = $c->session->{username};
    my $logger  = get_logger;
    my $profile = $c->profile;
    my $request = $c->request;
    my $mac = $c->portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    $provisioner->authorize($mac) if (defined($provisioner));
    $c->stash(
        post_uri            => '/tlsprofile/cert',
        destination_url     => 'eap-profile.html',
        certificate_cn      => $request->param_encoded("certificate_cn"),
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_email   => lc( $request->param_encoded("certificate_email")),
        service             => $request->param_encoded("service"),
        profile_list        => $Config{'pki'}{'profiles'},
        template            => 'pki.html',
        provisioner         => $provisioner,
        username            => $username,
        );
}
sub cert_p12 : Path('/eap-profile.html') : Args(0) {
    my ( $self, $c ) = @_;
    $c->response->body($c->stash->{'cert_content'});
    my $headers = $c->response->headers;
    $headers->content_type('application/x-pkcs12');
    my $certname = $c->stash->{'certifacte_cn'} . "p12";
    $headers->header( 'Content-Disposition', "attachment; filename=\"$certname\"" );
}


sub get_cert : Private {
    use bytes;
    my ($self,$c,) = @_;
    my $stash = $c->stash;
    my $uri = $Config{'pki'}{'uri'};
    my $username = $Config{'pki'}{'username'};
    my $password = $Config{'pki'}{'password'};
    my $email = $stash->{'certificate_email'};
    my $dot1x_username = $stash->{'certificate_cn'};
    my $organisation = $Config{'pki'}{'organisation'};
    my $state = $Config{'pki'}{'state'};
    my $profile = $stash->{'service'};
    my $country = $Config{'pki'}{'country'};
    my $certpwd = $stash->{'certificate_pwd'};
    my $response = '';
    my $curl = WWW::Curl::Easy->new; #$self->curl($function);
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

    $response = $response_body;
    $c->stash(
        cert_content    => $response_body,
    );
}
 
sub cert : Local {
    my ($self,$c,) = @_;
    $c->forward('validateform');
    $c->forward('get_cert');
    $c->forward('cert_p12');
}

sub validateform : Private {
    my ($self,$c,) = @_;
    $c->stash(
        service => $c->request->param('service'),
        certificate_cn => $c->request->param('certificate_cn'),
        certificate_email => $c->request->param('certificate_email'),
        certificate_pwd => $c->request->param('certificate_pwd'),
    );

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
