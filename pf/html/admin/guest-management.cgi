#!/usr/bin/perl
=head1 NAME

guest-management.cgi

=cut
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use POSIX;
use Readonly;
use Template;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
# required for dynamically loaded authentication modules
use lib INSTALL_DIR . "/conf";

use pf::class;
use pf::config;
use pf::email_activation;
use pf::iplog;
use pf::node;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest 1.10;
# called last to allow redefinitions
use pf::web::custom;

# constants
Readonly::Scalar my $GUEST_REGISTRATION => "guest-register";

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('guest-management.cgi');
Log::Log4perl::MDC->put('proc', 'guest-management.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %params;

# pull parameters from query string
foreach my $param($cgi->url_param()) {
  $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
  $params{$param} = $cgi->param($param);
}

# is user already logged in?
if (defined($session->param("login"))) {

    if (defined($cgi->param("action")) && $cgi->param("action") eq "logout") {
        $session->delete();
        pf::web::guest::generate_activation_login_page($cgi, $session, 0, "guest/mgmt_login.html");
        exit(0);

    } elsif (defined($cgi->param("action_print")) || defined($cgi->param("action_sendEmail"))) {

        my ($success, $error) = pf::web::guest::validate_registration($cgi, $session);
        if (!$success) {
            $logger->debug("guest registration form didn't pass validation");
            pf::web::guest::generate_registration_page( $cgi, $session, "/guests/manage", $error );
            exit(0);

        } else {
            $logger->debug("guest registration form passed validation");

            my $password = pf::web::guest::preregister( $cgi, $session );

            my $info = {
                'firstname' => $session->param("firstname"),
                'lastname' => $session->param("lastname"),
                'email' => $session->param("email"),
                'username' => $session->param("email"),
                'password' => $password,
                'valid_from' => $session->param("arrival_date"),
                'duration' => pf::web::guest::valid_access_duration($session->param("access_duration")),
            };

            # tear down session information
            $session->clear([ "firstname", "lastname", "email", "phone", "arrival_date", "access_duration" ]);

            # print page
            if (defined($cgi->param("action_print"))) {
                pf::web::guest::generate_registration_confirmation_page($cgi, $session, $info);
            }
            # otherwise email
            pf::web::guest::send_registration_confirmation_email($info);

            # return user to the guest registration page
            pf::web::guest::generate_registration_page(
                $cgi, $session, "/guests/manage", $pf::web::guest::REGISTRATION_CONTINUE
            );
        }
    }

    # no specific action, show guest registration page
    pf::web::guest::generate_registration_page( $cgi, $session, "/guests/manage" );
    exit(0);
} else {
    # auth
    my ($auth_return,$err) = pf::web::guest::auth($cgi, $session, "guest_managers");
    if ($auth_return != 1) {
        $logger->debug("authentication required");
        pf::web::guest::generate_activation_login_page($cgi, $session, $err, "guest/mgmt_login.html");
        exit(0);
    }
    pf::web::guest::generate_registration_page( $cgi, $session, "/guests/manage" );
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.
    
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
# vim: set autoindent:
