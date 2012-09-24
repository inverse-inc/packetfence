#!/usr/bin/perl

=head1 NAME

OAuth2.cgi

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

my %info;

# Pull username
$info{'pid'} = 1;

# Pull browser user-agent string
$info{'user_agent'} = $cgi->user_agent;

if (defined($cgi->url_param('o2'))) {
    $logger->info("Sending " . $portalSession->getClientMac() . "to OAuth2 - Provider:" . $cgi->url_param('o2') );
    pf::web::generate_o2_page( $portalSession );
    exit(0);
} elsif (defined($cgi->url_param('result')) && $cgi->url_param('result') eq "google") {
    my ($code,$email,$err) = pf::web::generate_o2_result( $portalSession, "google" );

    if ($code) {
      my $pid = $email;
      pf::web::web_node_register($portalSession, $pid, %info);
      pf::web::end_portal_session($portalSession);
    } else {
        exit(0);
    }
} elsif (defined($cgi->url_param('result')) && $cgi->url_param('result') eq "facebook") {
#Handle OAuth2 response from Facebook
    my ($code,$username,$err) = pf::web::generate_o2_result( $portalSession, "facebook" );

    if ($code) {
      my $pid = $username . "\@facebook.com";
      pf::web::web_node_register($portalSession, $pid, %info);
      pf::web::end_portal_session($portalSession);
    } else {
       exit(0);
    }
}
