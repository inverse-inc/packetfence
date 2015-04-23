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
use File::Basename;
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
    use Data::Dumper;
    $logger->info('username signed in:'. Dumper($username));
    my $pid = $node_info->{'pid'};
    #my $host = "";
    #my $ldapreq = "ldapsearch -h $host -s sub -b $basedn -D $binddn -w $passwd \"(cn=$username)\" | grep mail ";
    my $provisioner = $c->profile->findProvisioner($mac);
    #$provisioner->authorize($mac) if (defined($provisioner));
    $c->stash(
        post_uri            => '/tlsprofile/cert_process',
        certificate_cn      => $mac,
        certificate_pwd     => $request->param_encoded("certificate_pwd"),
        certificate_email   => lc( $request->param_encoded("certificate_email") || $request->param_encoded("email")),
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
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $node_info     = node_view($mac);
    my $pid           = $node_info->{'pid'};
    my $fh;
    open ($fh, '>', $certname);
    if (-e $certname) {
        $logger->info("Certificate for user \"$pid\" successfully created.");
    }
    else {
        $logger->info("The certificate file could not be saved for username \"$pid\"");
        $self->showError($c,"An error has occured while trying to save your certificate, please contact your IT support");
    }
    use Data::Dumper;
    $logger->info(Dumper($cert_data));
    print $fh "$cert_data\n";
    close $fh;
}

sub get_cert : Private {
    my ($self, $c) = @_;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $provisioner   = $c->profile->findProvisioner($mac);
    return unless $provisioner;
    my $pki_provider = $provisioner->getPkiProvider();
    my $cert_content = $pki_provider->get_cert;
    $c->stash(cert_content => $cert_content);
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
    $c->forward( 'Authenticate' => 'checkIfProvisionIsNeeded' );
    $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}{pid}, %{$c->stash->{info}}]);
    $c->forward( 'CaptivePortal' => 'endPortalSession' );
}

sub validateform : Private {
    my ($self, $c) = @_;
    my $logger = $c->log;
    my $pid    = "";
    my $portalSession = $c->portalSession;
    my $mac    = $portalSession->clientMac;
    unless ($c->has_errors) {
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
    }
    $c->stash(
        service           => $c->request->param('service'),
        certificate_cn    => $mac,
        certificate_email => $c->request->param('certificate_email'),
        certificate_pwd   => $c->request->param('certificate_pwd'),
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
    my $stash = $c->stash;
    #my $provisioner = $stash->{'provisioner'};
    #$logger->info('CA_PATH'.Dumper($provisioner));
    #my $cacert = $provisioner->{'ca_path'};
    #$logger->info('CA_PATH'.Dumper($cacert));
    my $capath = "/usr/local/pf/raddb/certs/TestEAP.pem";
    my $svrpath = "/usr/local/pf/raddb/certs/svr.pem";
    my $data = pf_run("openssl x509 -in $capath -fingerprint");
    my $cadata = pf_run("openssl x509 -in $capath -text");
    my $svrdata = pf_run("openssl x509 -in $svrpath -text");
    my $cafile = basename($capath);
    my $svrfile = basename($svrpath);
    $c->session( cacn => $cafile );
    $c->session( svrcn => $svrfile );
    $cadata =~ s/-----END CERTIFICATE-----\n.*//smg;
    $cadata =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    $c->session( cadata => $cadata );
    $svrdata =~ s/-----END CERTIFICATE-----\n.*//smg;
    $svrdata =~ s/.*-----BEGIN CERTIFICATE-----\n//smg;
    $c->session( svrdata => $svrdata );
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
