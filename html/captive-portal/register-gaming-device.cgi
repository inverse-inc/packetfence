#!/usr/bin/perl

=head1 NAME

register-gaming-device.cgi

=head1 SYNOPSYS

Handles captive-portal gaming registration

=cut

use CGI;
use Log::Log4perl;
use strict;
use warnings;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use pf::config;
use pf::web::gaming;
use pf::Portal::Session;
use pf::web;
use Readonly;
Readonly our $GAMING_CATEGORY  => "gaming_console";
Readonly our $SCRIPT => 'register-gaming-device.cgi';



sub main {
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger($SCRIPT);
    Log::Log4perl::MDC->put('proc', $SCRIPT);
    Log::Log4perl::MDC->put('tid', 0);

    my %params;
    my $portalSession   = new pf::Portal::Session();
    my $cgi             = $portalSession->cgi;
    my $session         = $portalSession->session;
    my $ip              = $cgi->remote_addr;
    my $mac             = $portalSession->getClientMac();

    my %info;

    # Pull username
#    $logger->info(Dumper(\$cgi));

    # Pull browser user-agent string
    $info{'user_agent'}=$cgi->user_agent;

    # pull parameters from query string
    foreach my $param($cgi->url_param()) {
        $params{$param} = $cgi->url_param($param);
    }
    foreach my $param($cgi->param()) {
        $params{$param} = $cgi->param($param);
    }

    my $pid = $session->param("login");
    #See if user is try to login and is not already authenticated
    if(!$pid && $cgi->param('username') ne '' && $cgi->param('password') ne '') {
      my ($auth_return,$err) = pf::web::gaming::authenticate($portalSession,$cgi, $session, \%info, $logger);
      if ($auth_return != 1) {
        pf::web::gaming::generate_login_page($portalSession);
      }
      else {
        pf::web::gaming::generate_registration_page($portalSession);
      }
    }
    #Verify is user is authenticated
    elsif (!$pid) {
      pf::web::gaming::generate_login_page($portalSession);
    }
    elsif (exists $params{cancel} )  {
        $session->delete();
        pf::web::gaming::generate_login_page($portalSession,'Registration canceled please try again');
    }
    #User is authenticated and requesting to register gaming device
    elsif (exists $params{'device_mac'}) {
        $info{pid} = $pid;
        my $device_mac = $params{'device_mac'};
        $portalSession->stash->{device_mac} = $device_mac;
        # register gaming device
        $info{'category'} = $GAMING_CATEGORY;
        my ($result,$msg) = pf::web::gaming::register_node($portalSession, $pid,$device_mac, %info);
        if($result) {
            pf::web::gaming::generate_landing_page($portalSession,$msg);
            $portalSession->session->delete();
        }
        else {
            pf::web::gaming::generate_registration_page($portalSession,$msg);
        }
    }
    #User is authenticated so display registration page
    else {
      pf::web::gaming::generate_registration_page($portalSession);
    }
    exit(0);
}

main();

=head1 AUTHOR

=head1 COPYRIGHT

Copyright (C) 2008-2012 Inverse inc.

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
