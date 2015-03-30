package captiveportal::PacketFence::Controller::TLSProfile;
use Moose;
use namespace::autoclean;
use WWW::Curl::Easy;
use Crypt::OpenSSL::PKCS12;
use pf::log;
use pf::config;
use pf::util;
use pf::node;
#use pf::web qw(i18n ni18n i18n_format render_template);
use pf::web::constants;
use List::MoreUtils qw(uniq any);
#use Readonly;
#use POSIX;
use pf::authentication;
use HTML::Entities;
#use URI::Escape::XS qw(uri_escape);
use pf::web;
use Email::Valid;


BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'tlsprofile', );

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
    my $node_info = node_view($mac);
    my $pid = $node_info->{'pid'};
    my $provisioner = $c->profile->findProvisioner($mac);
    #$provisioner->authorize($mac) if (defined($provisioner));
    $c->stash(
        post_uri            => '/tlsprofile/cert_process',
        certificate_cn      => $request->param_encoded("certificate_cn"),
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_email   => lc( $request->param_encoded("certificate_email")),
        template            => 'pki.html',
        provisioner         => $provisioner, 
        username            => $username,
        mac                 => $mac,
        pid                 => $pid,
        );
}
sub build_cert_p12 : Path : Args(0) {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $cert_data = $c->stash->{'cert_content'};
    my $cert = $c->stash->{'certificate_cn'} . ".p12";
    my $certname = "$cert_dir/$cert";
    $c->session( certificate_cn => "$cert" );
    my $pid = "";
    my $fh;
    open ($fh, '>', $certname);
    if (-e $certname) { 
        $logger->info("Certificate for user \"$pid\" successfully created."); 
    }
    else {
        $logger->info("The certificate file could not be saved for username \"$pid\"");
        $self->showError($c,"An error has occured while trying to save your certificate, please contact your IT support");
    }
    unless ( $c->has_errors ){
        my $portalSession = $c->portalSession;
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
    }
    print $fh "$cert_data\n";
    close $fh;
}

sub cert_Clean : Local {
    my ($self,$c) = @_;
  
}

sub get_cert : Private {
    use bytes;
    my ($self,$c) = @_;
    my $logger = $c->log;
    my $pid = "";
    unless ( $c->has_errors ){
        my $portalSession = $c->portalSession;
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
    }
    my $stash = $c->stash;
    my $session = $c->session;
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

    if ($curl_return_code == 0) {
        $c->stash( cert_content    => $response_body );
    }
    elsif ($curl_return_code == -1) {
        $logger->info("Username \"$pid\" certificate couldnt not be acquire, check out logs on the pki");
        $self->showError($c, "There was an issue with the generation of your certificate please contact your IT support.");
    }
}
 
sub cert_process : Local {
    my ($self,$c) = @_;
    my $logger = $c->log;
    $c->stash(info => $c->session->{info});
    $c->forward('validateform');
    $c->forward('get_cert');
    $c->forward('build_cert_p12');
    $c->forward('b64_cert');
    $c->forward('export_fingerprint');
    #$c->forward( 'Authenticate' => 'checkIfProvisionIsNeeded' );
    use Data::Dumper;
    $logger->info(Dumper($c->stash->{info}).'bob');
    $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}{pid}, %{$c->stash->{info}}]);
    $c->forward( 'CaptivePortal' => 'endPortalSession' );
}

sub checkIfProvisionIsNeeded : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $info = $c->stash->{info};
    my $logger = $c->log;
    my $mac = $portalSession->clientMac;
    my $profile = $c->profile;
    my $bob = $profile->findProvisioner($mac);
    if (defined( my $provisioner = $profile->findProvisioner($mac))) {
        if ($provisioner->authorize($mac) == 0) {
            $info->{status} = $pf::node::STATUS_PENDING;
            node_modify($mac, %$info);
            $c->stash(
                template    => $provisioner->template,
                provisioner => $provisioner,
            );
            $c->detach();
        }
    }
}

sub validateform : Private {
    my ($self,$c) = @_;
    my $logger = $c->log;
    my $pid = "";
    unless ( $c->has_errors ){
        my $portalSession = $c->portalSession;
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
    }
    $c->stash(
        service => $c->request->param('service'),
        my $usern = certificate_cn => $c->request->param('certificate_cn'),
        my $email_addr = certificate_email => $c->request->param('certificate_email'),
        my $userpwd = certificate_pwd => $c->request->param('certificate_pwd'),
    );
    #unless (Email::Valid->address($email_addr)){
    #    $logger->debug("Email enter is invalid for username \"$pid\"");
    #    $self->showError($c,"Please enter a vaild email address");
    #}
}

sub b64_cert : Local {
    my ($self,$c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $stash = $c->stash;
    my $cwd = $cert_dir;
    my $certfile = $stash->{'certificate_cn'};
    my $certp12 = "$cwd/$certfile.p12";
    my $b64 = pf_run("base64 $certp12");
    $c->session(
        b64_cert => $b64,
    );
}
sub export_fingerprint : Local {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $pid = "";
    unless ( $c->has_errors ){
        my $portalSession = $c->portalSession;
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
    }
    my $stash = $c->stash;
    my $cacert = $stash->{provisioner}->{ca_path};
    use Data::Dumper;
    $logger->info(Dumper($cacert).'cacert');
    my $data = pf_run("openssl x509 -in $cacert -fingerprint");
    #my $file = $1;
    #open FH, "< $cacert" or die $!;
    #my $data = "";

    #while (<FH>) {
    #    $data .= $_;
    #}
        
    $data =~ /.*\/([a-zA-Z0-9.]+)$/;
    $data =~ s/.*SHA1 Fingerprint=//smg; 
    $data =~ s/-----BEGIN CERTIFICATE-----\n.*//smg;
    $data =~ s/\:/\ /smg;
    $c->session( fingerprint => $data );
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
