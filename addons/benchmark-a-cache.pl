#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use Time::HiRes;
use Data::Dumper;
use pfconfig::timeme;
use Memory::Usage;
use Switch;

$pfconfig::timeme::VERBOSE = 0;

my $mem_usage = Memory::Usage->new();

$mem_usage->record("initializing cache");

print "Enter the cache name : (memcached, redis, bdb, pf::CHI) : ";
my $cache_name = <STDIN>;
chomp($cache_name);

my $cache;

switch($cache_name){
  case 'bdb' {
    use Cache::BDB;
    my %options = (
      cache_root => "/tmp",
      namespace => "Some::Namespace",
      default_expires_in => 300, # seconds
    );
    
    $cache = Cache::BDB->new(%options);
  }
  case 'memcached' {
    use Cache::Memcached;
    $cache = new Cache::Memcached {
        'servers' => [ "127.0.0.1:11211" ],
        'debug' => 0,
        'compress_threshold' => 10_000,
      };
  }
  case 'redis' {
    use Cache::Redis;
    $cache = Cache::Redis->new(
        server    => 'localhost:6379',
        namespace => 'cache:',
    );
  }
  case 'pf::CHI' {
    use pf::CHI;
    $cache = pf::CHI->new(namespace => 'switch.overlay');
  }
  else {
    print STDERR "Invalid cache name !";
    exit;
  }
}

my $switch = {
                 '_vlans' => {
                               'inline' => '6',
                               'voice' => '5',
                               'isolation' => '3',
                               'normal' => '1',
                               'macDetection' => '4',
                               'registration' => '2'
                             },
                 '_switchIp' => '127.0.0.1',
                 '_id' => '127.0.0.1',
                 '_deauthMethod' => undef,
                 '_inlineTrigger' => [],
                 '_access_lists' => {},
                 '_macSearchesMaxNb' => '30',
                 '_radiusSecret' => undef,
                 '_mode' => 'production',
                 '_cliEnablePwd' => undef,
                 '_SNMPAuthPasswordWrite' => undef,
                 '_sessionWrite' => undef,
                 '_cliUser' => undef,
                 '_macSearchesSleepInterval' => '2',
                 '_VlanMap' => 'Y',
                 '_normalVlan' => '1',
                 '_ip' => '127.0.0.1',
                 '_roles' => {
                               'isolation' => 'isolation',
                               'inline' => 'inline',
                               'voice' => 'voice',
                               'normal' => 'normal',
                               'macDetection' => 'macDetection',
                               'registration' => 'changed it'
                             },
                 '_SNMPAuthProtocolWrite' => undef,
                 '_SNMPPrivPasswordRead' => undef,
                 '_SNMPPrivPasswordWrite' => undef,
                 '_portalURL' => undef,
                 '_cliPwd' => undef,
                 '_AccessListMap' => 'N',
                 '_VoIPEnabled' => 0,
                 '_SNMPAuthProtocolRead' => undef,
                 '_sessionRead' => undef,
                 '_wsTransport' => undef,
                 '_wsPwd' => '',
                 '_switchMac' => undef,
                 '_voiceVlan' => '5',
                 '_SNMPPrivProtocolTrap' => undef,
                 '_macDetectionVlan' => '4',
                 '_SNMPAuthProtocolTrap' => undef,
                 '_error' => undef,
                '_SNMPCommunityWrite' => 'private',
                 '_inlineVlan' => '6',
                 '_controllerPort' => undef,
                 '_SNMPAuthPasswordRead' => undef,
                 '_SNMPAuthPasswordTrap' => undef,
                 '_SNMPUserNameWrite' => undef,
                 '_SNMPUserNameRead' => undef,
                 '_SNMPCommunityRead' => 'public',
                 '_SNMPUserNameTrap' => undef,
                 '_isolationVlan' => '3',
                 '_SNMPPrivProtocolRead' => undef,
                 '_RoleMap' => 'Y',
                 '_sessionControllerWrite' => undef,
                 '_SNMPVersion' => '1',
                 '_SNMPEngineID' => undef,
                 '_wsUser' => undef,
                 '_cliTransport' => 'Telnet',
                 '_uplink' => [
                                'dynamic'
                              ],
                 '_SNMPPrivPasswordTrap' => undef,
                 '_SNMPCommunityTrap' => 'public',
                 '_SNMPPrivProtocolWrite' => undef,
                 '_SNMPVersionTrap' => '1',
                 '_registrationVlan' => '2',
                 '_controllerIp' => undef
               };


$mem_usage->record("set switch in cache");
my $write = $cache->set('test', $switch);
print "Cache write gave : $write \n";

$mem_usage->record("get switch in cache");
pfconfig::timeme::time_me_x('getting switch', 1000, sub {
  my $switch = $cache->get('test');
#  print "IP of switch : ".$switch->{_ip}."\n";
}, 1);

#pfconfig::timeme::time_me_x('getting switch', 10, sub {
#  my $switch = $cache->get('test');
#  my $reg = $switch{_registrationVlan};
#}, 1);
#
#use pfconfig::namespaces::config::Switch;
#my $switches = pfconfig::namespaces::config::Switch->new->build;
#
#$cache->set('switches', $switches);
#
#pfconfig::timeme::timeme('getting switches', sub {
#  my $switches = $cache->get('switches');
#}, 1);

$mem_usage->dump();

