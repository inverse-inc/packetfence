#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pf::IniFiles;

my $defaults = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf.defaults");
my $cluster = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf", -import => $defaults);
my $node = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf.node", -import => $cluster);

$node->setval("general", "hostname", time);
$node->WriteConfig('/usr/local/pf/conf/pf.conf.node', -delta => 1);

$node->WriteConfig('/tmp/pf.conf.node.generated', -delta => 1);
$node->WriteConfig('/tmp/pf.conf.node.generated.full', -delta => 0);
