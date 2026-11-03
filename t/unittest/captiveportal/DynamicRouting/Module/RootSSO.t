#!/usr/bin/perl

=head1 NAME

RootSSO

=head1 DESCRIPTION

unit test for captiveportal::PacketFence::DynamicRouting::Module::RootSSO::is_valid_callback:
the admin SSO token is only sent back to an HTTPS admin URL of this server

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/html/captive-portal/lib);
    use setup_test_config;
}

use Test::More tests => 18;
use Test::MockModule;
use Test::NoWarnings;
use pf::config qw(%Config);
use pf::config::util;
use captiveportal::PacketFence::DynamicRouting::Module::RootSSO;

sub valid { captiveportal::PacketFence::DynamicRouting::Module::RootSSO::is_valid_callback($_[0]) }

# the test configuration: pf.pfdemo.org, management 10.0.0.13, internal interface 192.168.1.1
# portal_hosts reads the interfaces from pfconfig, which the tests running in parallel keep
# rebuilding (interfaces::management_network is a child of config::Switch), so pin its result
my $config_util = Test::MockModule->new('pf::config::util');
$config_util->mock('portal_hosts', sub { ('192.168.1.1', '192.168.2.1', '10.0.0.13', 'pf.pfdemo.org') });

ok(valid('https://pf.pfdemo.org:1443/admin#/login'), 'fqdn');
ok(valid('https://PF.pfdemo.org:1443/admin/#/login'), 'fqdn, case insensitive');
ok(valid('https://10.0.0.13:1443/admin/'), 'management IP');
ok(valid('https://192.168.1.1:1443/admin/'), 'IP of another interface');
ok(valid('https://pf:1443/admin/'), 'general.hostname');

ok(!valid('http://10.0.0.13:1443/admin/'), 'http is refused');
ok(!valid('https://evil.example.com/admin/'), 'foreign host');
ok(!valid('https://10.0.0.13@evil.example.com/admin/'), 'valid host given as userinfo');
ok(!valid('https://10.0.0.13.evil.example.com/admin/'), 'lookalike host');
ok(!valid('https://user@10.0.0.13/admin/'), 'userinfo on a valid host');
ok(!valid('https://10.0.0.13/portal/'), 'not an admin path');
ok(!valid('https://10.0.0.13/administrator/'), 'path only starting like /admin');
ok(!valid('javascript:alert(1)//10.0.0.13/admin/'), 'javascript: URL');
ok(!valid('//10.0.0.13/admin/'), 'scheme-relative URL');

{
    local $Config{admin_login}{sso_allowed_callback_hosts} = 'admin.example.org, other.example.org';
    ok(valid('https://admin.example.org/admin/'), 'host of sso_allowed_callback_hosts');
    ok(valid('https://other.example.org:8443/admin/'), 'second host of sso_allowed_callback_hosts, any port');
    ok(!valid('https://evil.example.com/admin/'), 'other hosts still refused');
}

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

