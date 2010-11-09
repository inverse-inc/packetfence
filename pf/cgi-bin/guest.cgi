#!/usr/bin/perl
#use Data::Dumper;
use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use Readonly;
use POSIX;

use constant INSTALL_DIR => '/usr/local/pf';
use constant SCAN_VID => 1200001;
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
use pf::web::guest;
# called last to allow redefinitions
use pf::web::custom;

# constants
Readonly::Scalar my $GUEST_REGISTRATION => "guest-register";

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
if (defined($params{'mode'}) && $params{'mode'} eq $GUEST_REGISTRATION) {

    # authenticate
    my ($auth_return, $err) = pf::web::guest::validate($cgi, $session);

    # authentication failed, return to guest registration page and show error message
    if ($auth_return != 1) {
        pf::web::guest::generate_registration_page($cgi, $session, $cgi->script_name(), $destination_url, $mac, $err);
        exit(0);
    }

    # Login successful, adding person (using edit in case person already exists)
    my $person_add_cmd = "$bin_dir/pfcmd 'person edit \""
        . $session->param("login")."\" "
        . "firstname=\"" . $session->param("firstname") . "\","
        . "lastname=\"" . $session->param("lastname") . "\","
        . "email=\"" . $session->param("email") . "\","
        . "telephone=\"" . $session->param("phone") . "\","
        . "notes=\"guest account\"'"
    ;
    $logger->info("Registering guest person with command: $person_add_cmd");
    `$person_add_cmd`;

    # grab additional info about the node
    $info{'pid'} = $session->param("login");
    $info{'user_agent'} = $cgi->user_agent;
    $info{'category'} = "guest";

    # unreg in 10 minutes
    $info{'unregdate'} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + 10*60 ));

    # register the node
    pf::web::web_node_register($cgi, $session, $mac, $info{'pid'}, %info);

    # add more info for the activation email
    $info{'firstname'} = $session->param("firstname");
    $info{'lastname'} = $session->param("lastname");
    $info{'telephone'} = $session->param("phone");

    $info{'subject'} = $Config{'general'}{'domain'}.': Email activation required';

    # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
    pf::email_activation::create_and_email_activation_code(
        $mac, $info{'pid'}, $info{'pid'}, $pf::email_activation::GUEST_TEMPLATE, %info
    );

    # Violation handling and redirection (accorindingly)
    my $count = violation_count($mac);

    if ($count == 0) {
        if ($Config{'network'}{'mode'} =~ /arp/i) {
            my $freemac_cmd = $bin_dir."/pfcmd manage freemac $mac";
            my $out = qx/$freemac_cmd/;
        }
        pf::web::generate_release_page($cgi, $session, $destination_url);
        $logger->info("registration url = $destination_url");
    } else {
        print $cgi->redirect("/cgi-bin/redir.cgi?destination_url=$destination_url");
        $logger->info("more violations yet to come for $mac");
    }

} else {
    # wipe web fields
    $cgi->delete('firstname', 'lastname', 'email', 'phone');

    # by default, show guest registration page
    pf::web::guest::generate_registration_page($cgi, $session, $cgi->script_name()."?mode=$GUEST_REGISTRATION",
        $destination_url, $mac);
}
