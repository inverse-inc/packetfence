#!/usr/bin/perl

=head1 NAME

MFA

=head1 DESCRIPTION

unit test for captiveportal::PacketFence::DynamicRouting::Module::MFA::execute_child:
an MFA triggered by the source but not configured blocks the user instead of
being skipped

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/html/captive-portal/lib);
    use setup_test_config;
}

use Test::More tests => 14;
use Test::MockModule;
use Test::NoWarnings;
use captiveportal::PacketFence::DynamicRouting::Module::MFA;

{
    package test::app;
    sub new { my ($class, %session) = @_; bless { session => {%session}, flash => {} }, $class }
    sub session { $_[0]{session} }
    sub flash { $_[0]{flash} }
    sub redirect { $_[0]{redirect} = $_[1] }
    sub request { $_[0] }
    sub parameters { {} }
    sub method { $_[0]{method} // 'GET' }
    sub hashed_params { {} }

    package test::mfa;
    sub id { $_[0]{id} }
    sub verify_response { 0 }
}

my ($app, $done);
my $module = Test::MockModule->new('captiveportal::PacketFence::DynamicRouting::Module::MFA');
$module->mock('app', sub { $app });
$module->mock('current_mac', sub { '00:11:22:33:44:55' });
$module->mock('done', sub { $done = 1 });
my $mfa_module = bless {}, 'captiveportal::PacketFence::DynamicRouting::Module::MFA';

{
    ($app, $done) = (test::app->new, 0);
    $mfa_module->execute_child;
    ok($done, "no MFA triggered: the module is done");
    is($app->{redirect}, undef, "no MFA triggered: no redirect");
}

{
    ($app, $done) = (test::app->new(mfa_id => ''), 0);
    $mfa_module->execute_child;
    ok($done, "an empty MFA id: the module is done");
    is($app->{redirect}, undef, "an empty MFA id: no redirect");
}

{
    ($app, $done) = (test::app->new(mfa_id => 'no-such-mfa'), 0);
    $mfa_module->execute_child;
    ok(!$done, "an MFA that is not configured: the module is not done");
    is($app->{redirect}, '/logout', "an MFA that is not configured: the user is logged out");
    like($app->flash->{error} // '', qr/multi-factor authentication is not available/i, "an MFA that is not configured: a dedicated error is shown");
    ok(!exists $app->session->{mfa_id}, "an MFA that is not configured: the MFA id is removed from the session");
}

{
    my $skipable = bless { skipable => 'enabled' }, 'captiveportal::PacketFence::DynamicRouting::Module::MFA';
    ($app, $done) = (test::app->new(mfa_id => 'no-such-mfa'), 0);
    $skipable->execute_child;
    ok($done, "a skipable MFA that is not configured: the module is done");
    is($app->{redirect}, undef, "a skipable MFA that is not configured: no redirect");
}

{
    # The POST branch shares the same failure path
    my $mfa = Test::MockModule->new('captiveportal::PacketFence::DynamicRouting::Module::MFA');
    $mfa->mock('get_mfa', sub { bless { id => 'totp' }, 'test::mfa' });
    $mfa->mock('username', sub { 'bob' });
    ($app, $done) = (test::app->new, 0);
    $app->{method} = 'POST';
    $mfa_module->execute_child;
    ok(!$done, "a wrong MFA response: the module is not done");
    is($app->{redirect}, '/logout', "a wrong MFA response: the user is logged out");
    like($app->flash->{error} // '', qr/unable to validate the multi-factor response/i, "a wrong MFA response: the response error is shown");
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
