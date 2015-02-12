package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
use WWW:Curl:Easy;

BEGIN { extends 'captiveportal::Base::Controller'; }
use pf::config;
use pf::log;
use pf::web::constants;
use pf::web::util;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::authentication;
use List::MoreUtils qw(uniq any);
use Readonly;
use POSIX;
use URI::Escape::XS qw(uri_escape);
use pf::web;



=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $username = $c->session->{username} || '';
    my $mac = $c->portalSession->clientMac;
    my $provisioner = $c->profile->findProvisioner($mac);
    $provisioner->authorize($mac) if (defined($provisioner));
    $provisioner->build_cert();
    $c->stash(
        template     => 'wireless-profile.xml',
        current_view => 'MobileConfig',
        provisioner  => $provisioner,
        username     => $username
        );
    if ( $mode && $mode eq $pf::web::constants::EAP_PROFILE ) {
        $c->forward('get_cert'); 
    }  

}

sub profile_xml : Path('/profile.xml') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{filename} = 'profile.xml';
    $c->forward('index');
}  

sub regPki : Private {
    my ( $self, $c ) = @_;
    my $logger  = get_logger;
    my $profile = $c->profile;
    my $request = $c->request;

    my $ad_type =
      pf::Authentication::Source::ADSource->meta->get_attribute('type')
      ->default;
    my $source = $profile->getSourceByType($ad_type);

    $c->stash(
        post_uri            => "$WEB::URL_EAP_PROFILE?mode=eap-profile",
        certificate_cn      => $request->param_encoded("certificate_cn"),
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_email   => lc( $request->param_encoded("certificate_email")),
        service             => $request->param_encoded("service"),
        profile_list        => $Config{'pki'}{'profiles'},
    );

    $c->stash( template => 'pki.html' );
}

sub get_cert : Private {
    use bytes;
    my ($self,$function,@args) = @_;
    my $uri = $Config{'pki'}{'uri'};
    my $username = $Config{'pki'}{'username'};
    my $password = $Config{'pki'}{'password'};
    my $email = $regPki{'certificate_email'};
    my $dot1x_username = $regPki{'certificate_cn'};
    my $organisation = $Config{'pki'}{'organisation'};
    my $state = $Config{'pki'}{'state'};
    my $profile = $regPKI{'service'};
    my $country = $Config{'pki'}{'country'};
    my $response;
    my $curl = WWW::Curl::Easy->new; #$self->curl($function);
    my $request = "username=$username&password=$password&cn=$dot1x_username&mail=$email&organisation=$organisation&st=$state&country=$country&profile=$profile"
    my $response_body;
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
    print $response;
    return $response;
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
