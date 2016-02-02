#!/usr/bin/perl
use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/html/captive-portal/lib';

use captiveportal::DynamicRouting::Application;
use captiveportal::DynamicRouting::RootModule;
use captiveportal::DynamicRouting::OrModule;
use captiveportal::DynamicRouting::AuthModule::SMS;
use captiveportal::DynamicRouting::AuthModule::Login;

use pf::Portal::ProfileFactory;
use pf::authentication;

my $app = sub {
    my $env = shift; # PSGI env
    my $session = $env->{'psgix.session'};
    my $req = Plack::Request->new($env);

    return $req->new_response(200)->finalize() if($req->path =~ /favicon/);

    my $mac = "00:11:22:33:44:55";
    my $profile = pf::Portal::ProfileFactory->instantiate($mac); 
    
    my $application = captiveportal::DynamicRouting::Application->new(session => $session, profile => $profile, request => $req);
    $application->session->{client_mac} = $mac;
    my $root_module = captiveportal::DynamicRouting::RootModule->new(id => 'root', app => $application, modules => []);
    my $or_module = captiveportal::DynamicRouting::OrModule->new(id => 'auth_or', app => $application, modules => [], parent => $root_module);
    my $sms_module = captiveportal::DynamicRouting::AuthModule::SMS->new(id => 'sms', source => pf::authentication::getAuthenticationSource('sms'), custom_fields => ["user_email"], app => $application, parent => $or_module);
    my $login_module = captiveportal::DynamicRouting::AuthModule::Login->new(id => 'login', source => pf::authentication::getAuthenticationSource('inverse'), custom_fields => [], app => $application, parent => $or_module);
    $or_module->add_module($sms_module);
    $or_module->add_module($login_module);
    $root_module->add_module($or_module);
    $application->root_module($root_module);

    $application->execute();


    my $res = $req->new_response(200); # new Plack::Response
    $res->body($application->template_output);
    $res->finalize;
}; 

builder {
    enable 'Session';
    $app;
};
