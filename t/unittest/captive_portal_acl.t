#!/usr/bin/perl

=head1 NAME

captive_portal_acl

=head1 DESCRIPTION

unit test for pf::captive_portal_acl: the generated access lists of the
registration and isolation roles (#7824)

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 17;
use Test::MockModule;
use pf::config qw(%Config);
use pf::captive_portal_acl;
use pf::Switch;

#This test will running last
use Test::NoWarnings;

# t/data/pf.conf: passthroughs zammitcorp.com (80, 443 and tcp 22), dinde.ca:tcp:2828,
# wildcards *.zamm.it *.yes.hello:1234 *.tld *.github.com; isolation.zammitcorp.com
my %dns = (
    'zammitcorp.com'           => ['198.51.100.10', '198.51.100.11'],
    'dinde.ca'                 => ['198.51.100.20'],
    'isolation.zammitcorp.com' => ['198.51.100.30'],
);
my $acl_module = Test::MockModule->new('pf::captive_portal_acl');
$acl_module->mock(resolve => sub { $dns{$_[0]} });
# the DNS servers of the networks come from the installed networks.conf: fix them
my %network_dns = (registration => ['203.0.113.53'], isolation => []);
$acl_module->mock(network_dns_servers => sub { @{ $network_dns{$_[0]} } });
my $switch_module = Test::MockModule->new('pf::Switch');
$switch_module->mock(node_view => sub { undef });

my $switch = pf::Switch->new({id => 'test', ip => '192.0.2.10', SNMPUseConnector => "N", radiusDeauthUseConnector => "N"});

$Config{fencing}{registration_access_list} = 'disabled';
$Config{fencing}{isolation_access_list} = 'disabled';
ok(!pf::captive_portal_acl::enabled('registration'), 'disabled by default for registration');
is(pf::captive_portal_acl::acls($switch, 'registration'), undef, 'no access list when disabled');
ok(!pf::captive_portal_acl::enabled('default'), 'never enabled for a regular role');

# the internal interfaces of t/data/pf.conf
is_deeply([pf::captive_portal_acl::addresses('registration')], ['192.168.1.1', '192.168.2.1', '203.0.113.53'], 'the addresses of the internal interfaces and the DNS servers of the registration networks');
is_deeply([pf::captive_portal_acl::addresses('isolation')], ['192.168.1.1', '192.168.2.1'], 'isolation: the internal interfaces only when its networks have no DNS server');

$Config{fencing}{registration_access_list} = 'enabled';
my $acls = pf::captive_portal_acl::acls($switch, 'registration');
is_deeply(
    $acls,
    [
        'permit udp any any eq 67',
        'permit udp any any eq 68',
        (map { (
            "permit udp any host $_ eq 53",
            "permit tcp any host $_ eq 53",
            "permit tcp any host $_ eq 80",
            "permit tcp any host $_ eq 443",
        ) } qw(192.168.1.1 192.168.2.1 203.0.113.53)),
        'permit tcp any host 198.51.100.20 eq 2828',
        'permit tcp any host 198.51.100.10 eq 80',
        'permit tcp any host 198.51.100.11 eq 80',
        'permit tcp any host 198.51.100.10 eq 443',
        'permit tcp any host 198.51.100.11 eq 443',
        'permit tcp any host 198.51.100.10 eq 22',
        'permit tcp any host 198.51.100.11 eq 22',
        'deny ip any any',
    ],
    'registration: DHCP, DNS and the portal on PacketFence, the resolved passthroughs, deny the rest'
);
is($acls->[-1], 'deny ip any any', 'the access list ends with a deny of everything');

$Config{fencing}{isolation_access_list} = 'enabled';
my $isolation = pf::captive_portal_acl::acls($switch, 'isolation');
is_deeply(
    [grep { /198\.51\.100/ } @$isolation],
    ['permit tcp any host 198.51.100.30 eq 80', 'permit tcp any host 198.51.100.30 eq 443'],
    'isolation: only the isolation passthroughs'
);

# the resolved passthroughs are cached for a while
delete $dns{'dinde.ca'};
ok((grep { /2828/ } @{ pf::captive_portal_acl::acls($switch, 'registration') }), 'the resolved passthroughs are cached');
%pf::captive_portal_acl::PASSTHROUGHS_CACHE = ();

# an unresolvable passthrough is left out, the rest stays
{
    my $log = Test::MockModule->new('Log::Log4perl::Logger');
    my @warnings;
    $log->mock(warn => sub { push @warnings, $_[1] });
    $acls = pf::captive_portal_acl::acls($switch, 'registration');
    ok(!(grep { /2828/ } @$acls), 'an unresolvable passthrough is left out');
    ok((grep { /dinde\.ca/ } @warnings), 'and reported');
}

# through the switch: the generated access list is the one of the role
my ($type, $switch_acls) = $switch->_getAccessListByName('registration', 'aa:bb:cc:dd:ee:ff');
is($type, 'role', 'the switch returns it as the role access list');
is($switch_acls, join("\n", @$acls), 'as the generated lines');

# an access list set on the switch entry wins
$switch->{_access_lists}{registration} = "permit ip any any";
($type, $switch_acls) = $switch->_getAccessListByName('registration', 'aa:bb:cc:dd:ee:ff');
is($switch_acls, 'permit ip any any', 'an access list set on the switch takes precedence');
delete $switch->{_access_lists}{registration};

# disabled again: nothing for the reserved role
$Config{fencing}{registration_access_list} = 'disabled';
($type, $switch_acls) = $switch->_getAccessListByName('registration', 'aa:bb:cc:dd:ee:ff');
is($switch_acls, undef, 'nothing when disabled');

# a regular role is unaffected
($type, $switch_acls) = $switch->_getAccessListByName('default', 'aa:bb:cc:dd:ee:ff');
is($switch_acls, undef, 'a regular role without ACLs is unaffected');

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
