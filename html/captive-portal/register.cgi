#!/usr/bin/perl

=head1 NAME

register.cgi 

=head1 SYNOPSYS

Handles captive-portal authentication, /status, de-registration, multiple registration pages workflow and viewing AUP

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::iplog;
use pf::locationlog;
use pf::node;
use pf::nodecategory;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::custom; # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('register.cgi');
Log::Log4perl::MDC->put('proc', 'register.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $mac = $portalSession->getClientMac();

# we need a valid MAC to identify a node
if ( !valid_mac($mac) ) {
    $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
    exit(0);
}

# Show the terms & conditions if requested
if (defined($cgi->url_param('mode')) && $cgi->url_param('mode') eq "aup") {
    $portalSession->stash->{'email'} = $portalSession->cgi->param("email");
    pf::web::generate_aup_standalone_page($portalSession);
    exit(0);
}

my %info;
my $params;

# The specified email address is used as the user ID
$info{'pid'} = lc $portalSession->cgi->param("email");

# Pull browser user-agent string
$info{'user_agent'} = $cgi->user_agent;

# Set default expiration to 30 days
$info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time('30D')));

$logger->debug($portalSession->getClientIp() . " - " . $mac . " on registration page (" . $info{'pid'} . ")");

my ($form_return, $err) = pf::web::validate_form($portalSession);
if ($form_return != 1) {
    $portalSession->stash->{'email'} = $portalSession->cgi->param("email");
    pf::web::generate_login_page($portalSession, $err);
    exit(0);
}

# Check if the email address matches an existing account
my $sql_type = pf::Authentication::Source::SQLSource->meta->get_attribute('type')->default;
my $source = pf::authentication::getAuthenticationSourceByType($sql_type);
if (defined $source) {
    my $username = $source->username_from_email($info{'pid'});
    if (defined $username) {
        $info{'pid'} = $params->{'username'} = $username;

        my $locationlog_entry = locationlog_view_open_mac($mac);
        if ($locationlog_entry) {
            $params->{connection_type} = $locationlog_entry->{'connection_type'};
            $params->{SSID} = $locationlog_entry->{'ssid'};
        }

        my $unregdate = &pf::authentication::match($source->id, $params, $Actions::SET_ACCESS_DURATION);
        if (defined $unregdate) {
            $unregdate = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($unregdate)));
        }
        else {
            $unregdate = &pf::authentication::match($source->id, $params, $Actions::SET_UNREG_DATE);
        }
        if (defined $unregdate) {
            $logger->debug("Set unregdate to $unregdate for email " . $portalSession->cgi->param("email") . " (pid $username, MAC $mac)");
            $info{'unregdate'} = $unregdate;
        }
    }
}

$logger->trace("Assign role 'default' for MAC $mac");
%info = (%info, (category => 'default'));

pf::web::web_node_register($portalSession, $info{'pid'}, %info);
pf::web::end_portal_session($portalSession);

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

