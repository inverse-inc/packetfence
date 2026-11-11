#!/usr/bin/perl

=head1 NAME

enforcement

=head1 DESCRIPTION

unit test for pf::enforcement

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use Test::MockModule;

#This test will running last
use Test::NoWarnings;

use pf::config qw(%ConfigNetworks);
use pf::enforcement;

untie %ConfigNetworks;
%ConfigNetworks = (
    '192.168.50.0' => { type => 'dns-enforcement', netmask => '255.255.255.0' },
    '192.168.60.0' => { type => 'vlan-registration', netmask => '255.255.255.0' },
);

ok(pf::enforcement::_is_in_dns_enforcement_network('192.168.50.10'), 'IP in a dns-enforcement network');
ok(!pf::enforcement::_is_in_dns_enforcement_network('192.168.60.10'), 'IP in a registration network');
ok(!pf::enforcement::_is_in_dns_enforcement_network('10.0.0.1'), 'IP outside of any network');
ok(!pf::enforcement::_is_in_dns_enforcement_network(undef), 'no IP');

my $ip;
my @warnings;
my $mock = Test::MockModule->new('pf::enforcement');
$mock->mock('locationlog_view_open_mac', sub { undef });
$mock->mock('get_logger', sub { bless {}, 'test::logger' });
{
    no strict 'refs';
    *{'test::logger::warn'} = sub { shift; push @warnings, "@_" };
    *{"test::logger::$_"} = sub { } for qw(info debug error);
}
my $ip4log = Test::MockModule->new('pf::ip4log');
$ip4log->mock('mac2ip', sub { $ip });

$ip = '192.168.50.10';
@warnings = ();
is(pf::enforcement::reevaluate_access('00:11:22:33:44:55', 'manage_register'), 1, 'DNS enforcement node without locationlog: no error');

$ip = '192.168.60.10';
@warnings = ();
pf::enforcement::reevaluate_access('00:11:22:33:44:55', 'manage_register');
is_deeply(\@warnings, ["Can't re-evaluate access because no open locationlog entry was found"], 'other node without locationlog still warns');

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
