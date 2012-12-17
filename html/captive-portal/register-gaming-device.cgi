#!/usr/bin/perl

# CUSTOM: this page is all custom, started as a copy of register.cgi

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

