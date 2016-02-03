#!/usr/bin/perl

use lib '/usr/local/pf/html/captive-portal/lib';
use lib '/usr/local/pf//lib';

use pf::Portal::ProfileFactory;
use captiveportal::DynamicRouting::Application;
use captiveportal::DynamicRouting::Factory;
use Plack::Request;

my $mac = "00:11:22:33:44:55";
my $profile = pf::Portal::ProfileFactory->instantiate($mac); 

my $application = captiveportal::DynamicRouting::Application->new(session => {}, profile => $profile, request => Plack::Request->new({}), root_module_id => "root_module");

my $factory = captiveportal::DynamicRouting::Factory->new();

$factory->build_application($application);

use Data::Dumper;
#print Dumper([$factory->graph->exterior_vertices]->[0]);
#print Dumper($factory->graph->edges_to("sms"));

print Dumper($application->root_module);
