#!/usr/bin/perl
package pf::web::provisioning;

=head1 NAME

pf::web::winprofil - handle the windows client request

=cut

=head1 DESCRIPTION

pf::web::winprofil return wifi profil, soh profil and certificate to the windows client. 

=cut

use strict;
use warnings;

use Apache2::RequestIO;
use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Access;
use Apache2::Connection;
use Log::Log4perl;
use pf::config;
use pf::iplog qw(ip2mac);
use pf::node;
use pf::web;
use pf::web::util;
use Apache2::Const;
use pf::Portal::Session;
use Template;
use pf::util;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        apple_provisioning
        windows_provisioning
        android_provisioning
    );
}


=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::web::provisioning");
   $logger->debug("instantiating new pf::web::provisioning");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item windows_provisioning

This handler get the session from memcached and if the node is reg it answer for the wifi xml profile
for the soh profil and the certificate.

=cut

sub windows_provisioning {
    my ($r) = @_;
    my $req = Apache2::Request->new($r);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    my $portalSession = pf::Portal::Session->new();
    
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    
    my $response;
    my $type;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });    

    my $return;
    my $mac;

    if (defined($portalSession->getGuestNodeMac)) {
        $mac = $portalSession->getGuestNodeMac;
    }
    else {
        $mac = $portalSession->getClientMac;
    }
    my $result = pf::web::util::get_memcached($mac,pf::web::util::get_memcached_conf());
    if (defined($result->{status}) && $result->{status} eq "reg") {
        if ($req->pnotes->{uri_winprofil} =~ /xml/) {
            $response = pf::web::generate_windows_provisioning_xml($portalSession);
            $req->content_type('text/xml');
            $req->no_cache(1);
            $req->print($response);
        }
        if ($req->pnotes->{uri_winprofil} =~ /soh/) {
            $response = pf::web::generate_windows_soh_xml($portalSession);
            $req->content_type('text/xml');
            $req->no_cache(1);
            $req->print($response);
            pf::web::util::del_memcached($mac,pf::web::util::get_memcached_conf());
        }
        if ($req->pnotes->{uri_winprofil} =~ /cert/) {
            ($response,$type) = pf::web::send_radius_certificate($portalSession);
            $req->content_type($type);
            $req->no_cache(1);
            $req->print($response);
        }
        return Apache2::Const::OK;
    }
    else {
        return Apache2::Const::FORBIDDEN;
    }

}

=item apple_provisioning

This handler generate the xml provisioning profil for apple stuff.

=cut

sub apple_provisioning {
    my ($r) = @_;
    my $req = Apache::SSLLookup->new($r);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    my $portalSession = pf::Portal::Session->new();

    # if not logged in, disallow access
    if (!defined($portalSession->session->param('username'))) {
        return Apache2::Const::FORBIDDEN;
    }

    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });

    $response = pf::web::generate_apple_mobileconfig_provisioning_xml($portalSession);
    $req->content_type('application/x-apple-aspen-config; charset=utf-8');
    $req->no_cache(1);
    $req->print($response);
    return Apache2::Const::OK;
}

=item android_provisioning

This handler generate the xml provisioning profil for android stuff.

=cut

sub android_provisioning {
    my ($r) = @_;
    my $req = Apache2::Request->new($r);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    my $portalSession = pf::Portal::Session->new();

    # if not logged in, disallow access
    if (!defined($portalSession->session->param('username'))) {
        return Apache2::Const::FORBIDDEN;
    }

    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });

    $response = pf::web::generate_apple_mobileconfig_provisioning_xml($portalSession);
    $req->content_type('application/x-apple-aspen-config; charset=utf-8');
    $req->no_cache(1);
    $req->print($response);
    return Apache2::Const::OK;
}

=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010, 2011, 2012 Inverse inc.

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
