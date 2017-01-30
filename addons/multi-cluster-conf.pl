#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pf::IniFiles;

my $defaults = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf.defaults");
my $global = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf", -import => $defaults);
my $cluster = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf.cluster", -import => $global);
my $node = pf::IniFiles->new(-file => "/usr/local/pf/conf/pf.conf.node", -import => $cluster);

$node->setval("general", "hostname", time);
$node->WriteConfig('/usr/local/pf/conf/pf.conf.node', -delta => 1);

$node->WriteConfig('/tmp/pf.conf.node.generated', -delta => 1);
$node->WriteConfig('/tmp/pf.conf.node.generated.full', -delta => 0);
