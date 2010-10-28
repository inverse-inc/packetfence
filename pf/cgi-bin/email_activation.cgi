#!/usr/bin/perl
#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use POSIX;

use constant INSTALL_DIR => '/usr/local/pf';
use constant SCAN_VID => 1200001;
use lib INSTALL_DIR . "/lib";

use pf::class;
use pf::config;
use pf::email_activation;
use pf::iplog;
use pf::node;
use pf::util;
use pf::web;
use pf::web::guest;
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('redir.cgi');
Log::Log4perl::MDC->put('proc', 'redir.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

my $result;
my $ip              = $cgi->remote_addr();
my $destination_url = $cgi->param("destination_url");
my $enable_menu     = $cgi->param("enable_menu");
my $mac             = ip2mac($ip);
my %params;
my %info;

# pull parameters from query string
foreach my $param($cgi->url_param()) {
  $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
  $params{$param} = $cgi->param($param);
}

# Correct POST
if (defined($params{'code'})) {

    # validate code
    my $node_mac = pf::email_activation::validate_code($params{'code'});
    if (!defined($node_mac)) {

        pf::web::generate_error_page($cgi, $session, "The activation code provided is invalid. "
            . "Reasons could be: it never existed, it was already used or has expired."
        );
        exit(0);
    }

    # expire in a week (at 2AM)
    # TODO extract expiration in a config param
    my $expiration = POSIX::strftime("%Y-%m-%d 02:00:00", localtime( time + 7*24*60*60 ));

    # change the unregdate of the node associated with the submitted code
    node_modify($node_mac, ('unregdate' => $expiration, 'status' => 'reg'));

    # send to success page
    pf::web::guest::generate_activation_confirmation_page($cgi, $session, $expiration);

} else {

    $logger->info("User has nothing to do here, redirecting to ".$Config{'trapping'}{'redirecturl'});
    print $cgi->redirect($Config{'trapping'}{'redirecturl'});

}
