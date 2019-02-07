#!/usr/bin/perl
=head1 NAME

integration/radius.t

=head1 DESCRIPTION

RADIUS module tests that are more end-to-end and affects the database.

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 9;
use Test::NoWarnings;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "integration/radius.t" );
Log::Log4perl::MDC->put( 'proc', "integration/radius.t" );
Log::Log4perl::MDC->put( 'tid',  0 );
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use pf::config;
use pf::radius::constants;
use pf::SwitchFactory;

BEGIN {
    use_ok('pf::radius');
    use_ok('pf::radius::custom');
}

# get an instance
my $radius = new pf::radius::custom();

# modify global $conf_dir so that t/data/switches.conf will be loaded instead of conf/switches.conf
$main::pf::config::conf_dir = "/usr/local/pf/t/data";

# Setup
# Wired MAC Auth example
my $radius_request = {
    'Calling-Station-Id' => "f0:4d:a2:cb:d9:c5",
    'NAS-IP-Address' => "192.168.0.2",
    'User-Name' => "f04da2cbd9c5",
    'NAS-Port-Type' => "Ethernet",
    'NAS-Port' => 12345,
};

# Answers
my $regist_vlan = 3;

# standard Wired MAC Auth query, expect registration
my $radius_response = $radius->authorize($radius_request);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_OK, (
        'Tunnel-Private-Group-ID'=> $regist_vlan,
        'Tunnel-Type'            => $RADIUS::VLAN,
        'Tunnel-Medium-Type'     => $RADIUS::ETHERNET)],
    "Wired MAC Auth request expect registration vlan"
);

# invalid switch
$radius_request->{'NAS-IP-Address'} = "10.0.0.100";
$radius_response = $radius->authorize($radius_request);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Switch is not managed by PacketFence")],
    "expect failure: switch doesn't exist"
);

# switch doesn't support Wired MAC Auth
$radius_request->{'NAS-IP-Address'} = "192.168.0.1";
$radius_response = $radius->authorize($radius_request);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Network device does not support this mode of operation")],
    "expect failure: switch doesn't support Wired MAC Auth"
);


# VoIP tests
my $switch = pf::SwitchFactory->instantiate('192.168.0.1');
$switch->{_VoIPEnabled} = 1;

$radius_response = $radius->_authorizeVoip(
    $WIRED_MAC_AUTH, $switch, $radius_request->{'Calling-Station-Id'},
    $radius_request->{'NAS-Port'}, $radius_request->{'User-Name'}, undef
);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_FAIL,
        ('Reply-Message' => "Server reported: VoIP authorization over RADIUS not supported for this network device")
    ], "expect failure: VoIP phone over RADIUS is not supported for this switch's model (yet)"
);

# Wired 802.1X example
$radius_request = {
    'Calling-Station-Id' => "f0:4d:a2:cb:d9:c5",
    'NAS-IP-Address' => "192.168.0.1",
    'User-Name' => "f04da2cbd9c5",
    'NAS-Port-Type' => "Ethernet",
    'NAS-Port' => 12345,
    'EAP-Type' => "mschap",
};

# switch doesn't support 802.1X
$radius_response = $radius->authorize($radius_request);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_FAIL, ('Reply-Message' => "Network device does not support this mode of operation")],
    "expect failure: switch doesn't support wired 802.1X"
);

# standard 802.1X query, expect registration
$radius_request->{'NAS-IP-Address'} = "192.168.0.2";
$radius_response = $radius->authorize($radius_request);
is_deeply($radius_response,
    [$RADIUS::RLM_MODULE_OK, (
        'Tunnel-Private-Group-ID'=> $regist_vlan,
        'Tunnel-Type'            => $RADIUS::VLAN,
        'Tunnel-Medium-Type'     => $RADIUS::ETHERNET)],
    "802.1X request expect registration vlan"
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

