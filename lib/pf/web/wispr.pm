#!/usr/bin/perl
package pf::web::wispr;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Access;
use Apache2::Connection;
use Data::Dumper;
use Log::Log4perl;
use pf::config;
use pf::iplog qw(ip2mac);
use pf::node;
use pf::web;
use Apache2::Const;
use pf::Portal::Session;
use Template;
use pf::util;



sub handler {

    my $r = (shift);
    my $req = Apache2::Request->new($r);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger('auth_handler');

    my $portalSession = pf::Portal::Session->new();
    
    $logger->warn($req->param("username"));

    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    my @auth_types = split( /\s*,\s*/, $portalSession->getProfile->getAuth );    
    
    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });    

    my $return;
    my %info;
    my $pid;
    my $mac;

    my $stash = {
        'code_result' => "100",
        'result' => "Authentication Failure",
    };


    foreach my $auth_type (@auth_types) {
        my $authenticator = pf::web::auth::instantiate($auth_type);
        return (0, undef) if (!defined($authenticator));
        $return = $authenticator->authenticate( $req->param("username"), $req->param("password") );
        if ($return) {
             $logger->warn("Authentification success");
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
             $info{'pid'} = 1;
             $pid = $req->param("username") if (defined $req->param("username"));
             $r->pnotes->{pid}=$pid;
             $r->pnotes->{user_agent}=$r->headers_in->{"User-Agent"};
             $r->pnotes->{mac} = $mac;
             
             last;
        }
    }
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

sub register {
    my $r = (shift);
    Log::Log4perl->init("$conf_dir/log.conf");
    my $logger = Log::Log4perl->get_logger('auth_handler');

    my %info;
    my $pid = $r->pnotes->{pid};
    my $mac = $r->pnotes->{mac};
    my $user_agent = $r->pnotes->{user_agent};

    $info{'pid'} = $r->pnotes->{pid};
    $info{'user_agent'} = $r->pnotes->{user_agent};
    $info{'mac'} = $r->pnotes->{mac};

    node_register( $mac, $pid, %info );
}
1;
