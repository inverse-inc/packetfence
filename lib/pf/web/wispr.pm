#!/usr/bin/perl
package pf::web::wispr;

=head1 NAME

pf::web::wispr - wispr implementation in mod_perl

=cut

=head1 DESCRIPTION

pf::web::wispr return xml when your authentication is success or failure.

=cut

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Access;
use Apache2::Connection;
use Apache2::Const;
use pf::log;
use Template;

use pf::authentication;
use pf::Authentication::constants;
use pf::config qw(
    %CAPTIVE_PORTAL
    %Config
    $HTTP
    $HTTPS
);
use pf::ip4log;
use pf::node;
use pf::web;
use pf::Portal::Session;
use pf::util;
use pf::locationlog;
use pf::enforcement qw(reevaluate_access);
use pf::constants::realm;

=head1 SUBROUTINES

=over

=item handler

The handler check in all authentication sources if the username and password are correct
and return an xml file to the wispr client

=cut

sub handler {

    my $r = (shift);
    my $req = Apache2::Request->new($r);
    my $logger = get_logger();

    $logger->trace("hitting wispr");

    my $portalSession = pf::Portal::Session->new();

    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });

    my %info;
    my $pid;
    my $mac;

    my $stash = {
        'code_result' => "100",
        'result' => "Authentication Failure",
    };

    # Trace the user in the apache log
    $r->user($req->param("username"));

    my ($return, $message, $source_id, $extra) = &pf::web::web_user_authenticate($portalSession,$req->param("username"),$req->param("password"));
    if ($return) {
        $logger->info("Authentification success for wispr client");
        $stash = {
                  'code_result' => "50",
                  'result' => "Authentication Success",
                 };

        if (defined($portalSession->getGuestNodeMac)) {
            $mac = $portalSession->getGuestNodeMac;
        }
        else {
            $mac = $portalSession->getClientMac;
        }

        $info{'pid'} = 'default';
        $pid = $req->param("username") if (defined $req->param("username"));
        $r->pnotes->{pid}=$pid;
        $r->pnotes->{mac} = $mac;
        %info = (%info, (pid => $pid), (user_agent => $r->headers_in->{"User-Agent"}), (mac =>  $mac));
    }


    my $params = { username => $pid };

    my $locationlog_entry = locationlog_view_open_mac($mac);
    if ($locationlog_entry) {
        $params->{connection_type} = $locationlog_entry->{'connection_type'};
        $params->{SSID} = $locationlog_entry->{'ssid'};
        $params->{realm} = $locationlog_entry->{'realm'};
    }
    $params->{context} = $pf::constants::realm::PORTAL_CONTEXT;
    my $matched = pf::authentication::match2($source_id, $params, $extra);
    if ($matched) {
        my $values = $matched->{values};
        my $role = $values->{$Actions::SET_ROLE};
        my $unregdate = $values->{$Actions::SET_UNREG_DATE};

        # This appends the hashes to one another. values returned by authenticator wins on key collision
        if (defined $role) {
            $logger->warn("Got role $role for username $pid");
            %info = (%info, (category => $role));
        }

        if (defined $unregdate) {
            $logger->trace("Got unregdate $unregdate for username $pid");
            %info = (%info, (unregdate => $unregdate));
        }
    }
    my $time_balance = &pf::authentication::match($source_id, $params, $Actions::SET_TIME_BALANCE);
    my $bandwidth_balance = &pf::authentication::match($source_id, $params, $Actions::SET_BANDWIDTH_BALANCE);
    $info{'time_balance'} = pf::util::normalize_time($time_balance) if (defined($time_balance));
    $info{'bandwidth_balance'} = pf::util::unpretty_bandwidth($bandwidth_balance) if (defined($bandwidth_balance));
    $r->pnotes->{info}=\%info;
    $template->process( "response_wispr.tt", $stash, \$response ) || $logger->error($template->error());
    $r->content_type('text/xml');
    $r->no_cache(1);
    $r->print($response);
    if (defined($pid)) {
        $r->handler('modperl');
        $r->set_handlers(PerlCleanupHandler => \&register);
    }
    return Apache2::Const::OK;

}

=item register

Register the node if the authentication was successfull

=cut

sub register {
    my $r = (shift);
    my $mac = $r->pnotes->{mac};
    node_register( $mac,$r->pnotes->{pid}, %{$r->pnotes->{info}} );
    reevaluate_access( $mac, 'manage_register' );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
