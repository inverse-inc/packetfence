#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use File::Basename qw(basename);
Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use Test::More tests => 7;

use lib '/usr/local/pf/lib';
use pf::config;

BEGIN { 
    use_ok('pf::radius'); 
    use_ok('pf::radius::custom');
}

# Constants copied out of the radius rlm_perl module
use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
use constant    RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
use constant    RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
use constant    RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
use constant    RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
use constant    RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
use constant    RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
use constant    RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
use constant    RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
use constant    RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

# modify global $conf_dir so that t/data/switches.conf will be loaded instead of conf/switches.conf
$main::pf::config::conf_dir = "/usr/local/pf/t/data";

# test the object
my $radius = new pf::radius::custom();
isa_ok($radius, 'pf::radius');

# subs
can_ok($radius, qw(
    authorize
    doWeActOnThisCall
    doWeActOnThisCall_wireless
    doWeActOnThisCall_wired
    _identify_connection_type
    authorize_voip
));

# Setup
# MAB example
my $nas_port_type  = "Ethernet";
my $switch_ip      = "192.168.0.1";
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
    [RLM_MODULE_OK, (
        'Tunnel-Private-Group-ID'=> $regist_vlan,
        'Tunnel-Type'            => 13,
        'Tunnel-Medium-Type'     => 6)],
    "MAB request expect registration vlan"
);

# invalid switch
$switch_ip = "10.0.0.100";
$radius_response = $radius->authorize($nas_port_type, $switch_ip, $request_is_eap, $mac, $port, $user_name, $ssid);
is_deeply($radius_response, 
    [RLM_MODULE_FAIL, undef],
    "expect failure: switch doesn't exist"
);

# VoIP tests
my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('192.168.0.1');
$switch->{_VoIPEnabled} = 1;

$radius_response = $radius->authorize_voip(WIRED_MAC_AUTH_BYPASS, $switch, $mac, $port, $user_name, $ssid);
is_deeply($radius_response,
    [RLM_MODULE_FAIL, undef],
    "expect failure: VoIP phone on radius is not supported yet"
);

