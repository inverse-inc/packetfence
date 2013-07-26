#!/usr/bin/perl

=head1 NAME

oauth2.cgi

=head1 SYNOPSYS

Handles captive-portal OAuth2 Authentication

=cut
use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use URI::Escape qw(uri_escape);
use Net::OAuth2::Client;
use HTML::Entities;

use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('oauth2.cgi');
Log::Log4perl::MDC->put('proc', 'oauth2.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();

# we need a valid MAC to identify a node
if ( !valid_mac($portalSession->getClientMac()) ) {
  $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
  pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
  exit(0);
}

my $source_type = undef;
my %info;
my $pid;

# Pull username
$info{'pid'} = "admin";

# Pull browser user-agent string
$info{'user_agent'} = $cgi->user_agent;

if (defined($cgi->url_param('provider'))) {
    $logger->info("Sending " . $portalSession->getClientMac() . "to OAuth2 - Provider:" . $cgi->url_param('provider') );
    pf::web::generate_oauth2_page( $portalSession );
    exit(0);
} elsif (defined($cgi->url_param('result')) && $cgi->url_param('result') eq "google") {
    my ($code,$email,$err) = pf::web::generate_oauth2_result( $portalSession, "google" );
    $source_type = pf::Authentication::Source::GoogleSource->meta->get_attribute('type')->default;

    if ($code) {
        $pid = $email;
    } else {
        exit(0);
    }
} elsif (defined($cgi->url_param('result')) && $cgi->url_param('result') eq "facebook") {
#Handle OAuth2 response from Facebook
    my ($code,$username,$err) = pf::web::generate_oauth2_result( $portalSession, "facebook" );
    $source_type = pf::Authentication::Source::FacebookSource->meta->get_attribute('type')->default;

    if ($code) {
       $pid = $username . "\@facebook.com";
    } else {
       exit(0);
    }
} elsif (defined($cgi->url_param('result')) && $cgi->url_param('result') eq "github") {
#Handle OAuth2 response from Github
    my ($code,$email,$err) = pf::web::generate_oauth2_result( $portalSession, "github" );
    $source_type = pf::Authentication::Source::GithubSource->meta->get_attribute('type')->default;

    if ($code) {
      $pid = $email;
    } else {
       exit(0);
    }
}

my $source_id = $portalSession->getProfile->getSourceByType($source_type);

# Setting access timeout and role (category) dynamically
$info{'unregdate'} = &pf::authentication::match($source_id, {username => $pid}, $Actions::SET_ACCESS_DURATION);

if (defined $info{'unregdate'}) {
    $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($info{'unregdate'})));
}
else {
    $info{'unregdate'} = &pf::authentication::match($source_id, {username => $pid}, $Actions::SET_UNREG_DATE);
}

$info{'category'} = &pf::authentication::match($source_id, {username => $pid}, $Actions::SET_ROLE);

pf::web::web_node_register($portalSession, $pid, %info);
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
