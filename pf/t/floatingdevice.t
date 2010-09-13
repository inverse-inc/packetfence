#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use File::Basename qw(basename);
Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use Test::More tests => 13;
use Test::MockModule;
use Test::MockObject::Extends;

use lib '/usr/local/pf/lib';
use pf::config;
use pf::SwitchFactory;

BEGIN { use pf::SNMP; }
BEGIN {
    use_ok('pf::floatingdevice');
    use_ok('pf::floatingdevice::custom');
}

my $FAILURE = 0;
my $SUCCESS = 1;

# test the object
my $fd = new pf::floatingdevice();
isa_ok($fd, 'pf::floatingdevice');

# subs
can_ok($fd, qw(
    enablePortConfig
    disablePortConfig
));

my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('192.168.0.60');
my $switch_port = '10001';
my $switch_locker;
my $result;

# Make the object mockable
$switch  = Test::MockObject::Extends->new( $switch );

# TODO: first statement repeated to correctly init hash (should fix with less hackish perl)
$main::pf::config::ConfigFloatingDevices{'bb:bb:cc:dd:ee:ff'}{'trunkPort'} = 1;
$main::pf::config::ConfigFloatingDevices{'bb:bb:cc:dd:ee:ff'}{'trunkPort'} = 1;
$main::pf::config::ConfigFloatingDevices{'bb:bb:cc:dd:ee:ff'}{'taggedVlan'} = '1,2,3';
$main::pf::config::ConfigFloatingDevices{'bb:bb:cc:dd:ee:ff'}{'pvid'} = '10';

# Now testing enablePortConfig

# testing all failure cases
$switch->mock('disablePortSecurityByIfIndex', sub { return (0); });
$result = $fd->enablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "enablePortConfig: failed to disable port-security on port");
$switch->unmock('disablePortSecurityByIfindex');

$switch->mock('disablePortSecurityByIfIndex', sub { return (1); });
$switch->mock('enablePortConfigAsTrunk', sub { return (0); });
$result = $fd->enablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "enablePortConfig: failed to configure trunk");
$switch->unmock('enablePortConfigAsTrunk');

$switch->mock('enablePortConfigAsTrunk', sub { return (1); });
$switch->mock('setVlan', sub { return (0); });
$result = $fd->enablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "enablePortConfig: failed to set PVID on port");
$switch->unmock('setVlan');

$switch->mock('setVlan', sub { return (1); });
$switch->mock('setIfLinkUpDownTrapEnable', sub { return (0); });
$result = $fd->enablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "enablePortConfig: failed to enable LinkDown traps on port");
$switch->unmock('setIfLinkUpDownTrapEnable');

# testing success
$switch->mock('setIfLinkUpDownTrapEnable', sub { return (1); });
$result = $fd->enablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $SUCCESS, "enablePortConfig: testing success");
$switch->unmock('setIfLinkUpDownTrapEnable');

# Now testing disablePortConfig

$switch->mock('setIfLinkUpDownTrapEnable', sub { return (0); });
$result = $fd->disablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "disablePortConfig: failed to disable LinkDown traps on port");
$switch->unmock('setIfLinkUpDownTrapEnable');

$switch->mock('setIfLinkUpDownTrapEnable', sub { return (1); });
$switch->mock('isTrunkPort', sub { return (1); });
$switch->mock('disablePortConfigAsTrunk', sub { return (0); });
$result = $fd->disablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "disablePortConfig: failed to deconfigure trunk");
$switch->unmock('disablePortConfigAsTrunk');

$switch->mock('setMacDetectionVlan', sub { return (1); });
$switch->mock('enablePortSecurityByIfIndex', sub { return (0); });
$result = $fd->disablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $FAILURE, "disablePortConfig: failed to disable port-security on port");
$switch->unmock('enablePortSecurityByIfIndex');

# testing success
$switch->mock('enablePortSecurityByIfIndex', sub { return (1); });
$result = $fd->disablePortConfig('bb:bb:cc:dd:ee:ff', $switch, $switch_port, $switch_locker);
is($result, $SUCCESS, "disablePortConfig: testing success");

