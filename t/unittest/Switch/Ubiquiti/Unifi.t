#!/usr/bin/perl

=head1 NAME

Unifi

=head1 DESCRIPTION

unit test for pf::Switch::Ubiquiti::Unifi

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::More tests => 5;
use Test::MockModule;
use pf::Switch::Ubiquiti::Unifi;
use pf::locationlog;
use pf::dal::locationlog;
use pf::dal::node;
use pf::dal::locationlog_history;

my $mac = '00:65:80:65:00:01';
my $ap  = 'aa:bb:cc:dd:ee:01';
pf::dal::node->remove_items(-where => { mac => $mac });
pf::dal::locationlog->remove_items(-where => { mac => $mac });
pf::dal::locationlog_history->remove_items(-where => { mac => $mac });
pf::dal::node->new({ mac => $mac })->insert;

my @sent;
my $mock = Test::MockModule->new('pf::Switch');
$mock->mock('handleRadiusDisconnect', sub { push @sent, $_[2]; return { Code => 'Disconnect-ACK' } });
$mock->mock('radius_deauth_connection_info', sub { {} });

my $switch = pf::Switch::Ubiquiti::Unifi->new({ id => '10.0.0.1', ip => '10.0.0.1', radiusSecret => 'x' });

# 1. no locationlog at all
@sent = ();
$switch->radiusDisconnect($mac);
ok(!exists $sent[0]{'NAS-Identifier'}, 'no locationlog: no empty NAS-Identifier');

# 2. closed locationlog (node deleted / disconnected)
pf::dal::locationlog->new({ mac => $mac, switch => '10.0.0.1', switch_ip => '10.0.0.1', switch_mac => $ap,
    port => 0, vlan => 1, connection_type => 'Wireless-802.11-NoEAP', start_time => '2026-10-11 10:00:00',
    end_time => '2026-10-11 10:05:00' })->insert;
@sent = ();
$switch->radiusDisconnect($mac);
is($sent[0]{'NAS-Identifier'}, 'aabbccddee01', 'closed locationlog: last AP used');
is($sent[0]{'Calling-Station-Id'}, '00-65-80-65-00-01', 'Calling-Station-Id format');

# 3. open locationlog on another AP wins
pf::dal::locationlog->update_items(-set => { switch_mac => 'aa:bb:cc:dd:ee:02', end_time => '0000-00-00 00:00:00' }, -where => { mac => $mac });
@sent = ();
$switch->radiusDisconnect($mac);
is($sent[0]{'NAS-Identifier'}, 'aabbccddee02', 'open locationlog: current AP used');

# 4. caller attributes still merged
@sent = ();
$switch->radiusDisconnect($mac, { 'NAS-IP-Address' => '10.0.0.9' });
is($sent[0]{'NAS-IP-Address'}, '10.0.0.9', 'additional attributes merged');


pf::dal::locationlog->remove_items(-where => { mac => $mac });
pf::dal::locationlog_history->remove_items(-where => { mac => $mac });
pf::dal::node->remove_items(-where => { mac => $mac });

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

1;

