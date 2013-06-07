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
use Log::Log4perl;
use pf::authentication;
use pf::config;
use pf::iplog qw(ip2mac);
use pf::node;
use pf::web;
use Apache2::Const;
use pf::Portal::Session;
use Template;
use pf::util;
use pf::locationlog;
use pf::enforcement;

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
    my $logger = Log::Log4perl->get_logger('auth_handler');
    $logger->warn("hitting wispr");
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

    my ($return, $message) = &pf::web::web_user_authenticate($portalSession);
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
        $mac = $req->param('mac'); 
        $info{'pid'} = 'admin';
        $pid = $req->param("username") if (defined $req->param("username"));
        $r->pnotes->{pid}=$pid;
        $r->pnotes->{user_agent}=$r->headers_in->{"User-Agent"};
        $r->pnotes->{mac} = $mac;
        %info = (%info, (pid => $pid), (user_agent => $r->headers_in->{"User-Agent"}), (mac =>  $mac));
    }


    my $params = { username => $pid };
    # TODO : add current_time and computer_name
    my $locationlog_entry = locationlog_view_open_mac($mac);
    if ($locationlog_entry) {
        $params->{connection_type} = $locationlog_entry->{'connection_type'};
        $params->{SSID} = $locationlog_entry->{'ssid'};
    }

    # obtain node information provided by authentication module. We need to get the role (category here)
    # as web_node_register() might not work if we've reached the limit
    my $value = &pf::authentication::match(undef, $params, $Actions::SET_ROLE);

    $logger->warn("Got role $value for username $pid");

    # This appends the hashes to one another. values returned by authenticator wins on key collision
    if (defined $value) {
        %info = (%info, (category => $value));
    }

    $value = &pf::authentication::match(undef, $params, $Actions::SET_ACCESS_DURATION);

    if (defined $value) {
        $logger->trace("No unregdate found - computing it from access duration");
        $value = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($value)));
    }
    else {
        $logger->trace("Unregdate found, we use it right away");
        $value = &pf::authentication::match(undef, $params, $Actions::SET_UNREG_DATE);
    }

    $logger->trace("Got unregdate $value for username $pid");

    if (defined $value) {
        %info = (%info, (unregdate => $value));
    }
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
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger('auth_handler');

    my %info;
    my $pid = $r->pnotes->{pid};
    my $mac = $r->pnotes->{mac};

    node_register( $mac, $pid, %{$r->pnotes->{info}} );
    pf::enforcement::reevaluate_access( $mac, 'manage_register', (force => $TRUE) );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

