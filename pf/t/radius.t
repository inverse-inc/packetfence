#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use File::Basename qw(basename);
Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use Test::More tests => 10;

use lib '/usr/local/pf/lib';
use pf::config;
use pf::radius::constants;

BEGIN { 
    use_ok('pf::radius'); 
    use_ok('pf::radius::custom');
}

# modify global $conf_dir so that t/data/switches.conf will be loaded instead of conf/switches.conf
$main::pf::config::conf_dir = "/usr/local/pf/t/data";

# test the object
my $radius = new pf::radius::custom();
isa_ok($radius, 'pf::radius');

# subs
can_ok($radius, qw(
    authorize
    _doWeActOnThisCall
    _doWeActOnThisCallWireless
    _doWeActOnThisCallWired
    _identifyConnectionType
    _authorizeVoip
    _translateNasPortToIfIndex
    _isSwitchSupported
    _switchUnsupportedReply
));

# Setup
# MAB example
my $nas_port_type  = "Ethernet";
my $switch_ip      = "192.168.0.2";
my $request_is_eap = 0;
my $mac            = "aa:bb:cc:dd:ee:ff";
my $port           = 12345;
my $user_name      = "aabbccddeeff";
my $ssid           = "";

# Answers
my $regist_vlan = 3;

# standard MAB query, expect registration
my $radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [$RADIUS::RLM_MODULE_OK, (
        'Tunnel-Private-Group-ID'=> $regist_vlan,
        'Tunnel-Type'            => 13,
        'Tunnel-Medium-Type'     => 6)],
    "MAB request expect registration vlan"
);

# invalid switch
$switch_ip = "10.0.0.100";
$radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [$RADIUS::RLM_MODULE_FAIL, undef],
    "expect failure: switch doesn't exist"
);

# switch doesn't support MAB
$switch_ip = "192.168.0.1";
$radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [$RADIUS::RLM_MODULE_FAIL, undef],
    "expect failure: switch doesn't support MAB"
);


# VoIP tests
my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('192.168.0.1');
$switch->{_VoIPEnabled} = 1;

$radius_response = $radius->_authorizeVoip(WIRED_MAC_AUTH_BYPASS, $switch, $mac, $port, $user_name, $ssid);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_FAIL, undef],
    "expect failure: VoIP phone on radius is not supported yet"
);

# Wired 802.1X example
$nas_port_type  = "Ethernet";
$switch_ip      = "192.168.0.1";
$request_is_eap = 1;
$mac            = "aa:bb:cc:dd:ee:ff";
$port           = 12345;
$user_name      = "aabbccddeeff";
$ssid           = "";

# switch doesn't support 802.1X 
$radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [$RADIUS::RLM_MODULE_FAIL, undef],
    "expect failure: switch doesn't support wired 802.1X"
);

# standard 802.1X query, expect registration
$switch_ip      = "192.168.0.2";
$radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [$RADIUS::RLM_MODULE_OK, (
        'Tunnel-Private-Group-ID'=> $regist_vlan,
        'Tunnel-Type'            => 13,
        'Tunnel-Medium-Type'     => 6)],
    "802.1X request expect registration vlan"
);
