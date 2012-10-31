#!/usr/bin/perl
package pf::web::winprofil;

=head1 NAME

pf::web::winprofil - windows profil implementation in mod_perl

=cut

=head1 DESCRIPTION

pf::web::winprofil return xml profil cert file and soh profil to the windows client. 

=cut

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Access;
use Apache2::Connection;
use Log::Log4perl;
use pf::config;
use pf::iplog qw(ip2mac);
use pf::node;
use pf::web;
use Apache2::Const;
use pf::Portal::Session;
use Template;
use pf::util;


=head1 SUBROUTINES

=over

=item handler

The handler check in all authentication sources if the username and password are correct
and return an xml file to the wispr client

=cut

sub handler {

    my $r = (shift);
    my $req = Apache2::Request->new($r);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger('pf::web::winprofil');

    my $portalSession = pf::Portal::Session->new();
    
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    
    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });    

    my $return;
    my %info;
    my $pid;
    my $mac;
    my $type;

    $logger->warn($r->pnotes->{uri_winprofil});
    if ($r->pnotes->{uri_winprofil} =~ /xml/) {
        $response = pf::web::generate_windows_provisioning_xml($portalSession);
        $r->content_type('text/xml');
        $r->no_cache(1);
        $r->print($response);
    }
    if ($r->pnotes->{uri_winprofil} =~ /soh/) {
        $response = pf::web::generate_windows_soh_xml($portalSession);
        $r->content_type('text/xml');
        $r->no_cache(1);
        $r->print($response);
    }
    if ($r->pnotes->{uri_winprofil} =~ /cert/) {
        ($response,$type) = pf::web::send_radius_certificate($portalSession);
        $r->content_type($type);
        $r->no_cache(1);
        $r->print($response);
    }
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
