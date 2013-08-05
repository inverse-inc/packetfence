#!/usr/bin/perl

=head1 NAME

mobile-confirmation.cgi 

=head1 SYNOPSYS

Handles captive-portal SMS authentication.

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use POSIX;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest;
# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('mobile-confirmation.cgi');
Log::Log4perl::MDC->put('proc', 'mobile-confirmation.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();

# we need a valid MAC to identify a node
if ( !valid_mac($portalSession->getClientMac()) ) {
    $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
    exit(0);
}

$logger->info($portalSession->getClientIp() . " - " . $portalSession->getClientMac()  . " on mobile confirmation page");

my %info;

# FIXME to enforce 'harder' trapping (proper workflow) once this all work
# put code as main if () and provide a way to unset session in template
if ( $portalSession->getCgi->param("pin") ) {

    $logger->info("Entering guest authentication by SMS");
    my ($auth_return, $err) = pf::web::guest::web_sms_validation($portalSession);
    if ( $auth_return != 1 ) {
        # Invalid PIN -- redirect to confirmation template 
        $logger->info("Loading SMS confirmation page");
        pf::web::guest::generate_sms_confirmation_page($portalSession, $ENV{REQUEST_URI}, $err);
        return (0);
    }

    $logger->info("Valid PIN -- Registering user");
   
    my $pid = $portalSession->getSession->param("guest_pid") || "admin";
    my $sms_type = pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default;
    my $source_id = $portalSession->getProfile->getSourceByType($sms_type);
    my $auth_params = { 'username' => $pid };

    # Setting access timeout and role (category) dynamically
    $info{'unregdate'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ACCESS_DURATION);

    if (defined $info{'unregdate'}) {
        $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($info{'unregdate'})));
    }
    else {
        $info{'unregdate'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_UNREG_DATE);
    }

    $info{'category'} = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ROLE);

    pf::web::web_node_register($portalSession, $pid, %info);

    # clear state that redirects to the Enter PIN page
    $portalSession->getSession->clear(["guest_pid"]);

    pf::web::end_portal_session($portalSession);

} elsif ($portalSession->getCgi->param("action_confirm")) {
    # No PIN specified
    pf::web::guest::generate_sms_confirmation_page($portalSession, $ENV{REQUEST_URI});
} else {
    pf::web::generate_registration_page($portalSession, 1);
}

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
