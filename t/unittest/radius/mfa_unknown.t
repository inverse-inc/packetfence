#!/usr/bin/perl

=head1 NAME

mfa_unknown

=head1 DESCRIPTION

unit test for pf::radius::mfa_pre_auth and pf::radius::mfa_post_auth with a
source action naming an MFA that is not configured

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
use pf::radius;
use pf::Authentication::constants;
use pf::radius::constants;

{
    package test::profile;
    sub new { bless {}, $_[0] }
    sub getFilteredAuthenticationSources { () }
}

my $matched;
my $authentication = Test::MockModule->new('pf::authentication');
$authentication->mock('match2', sub { $matched });
my $profile_factory = Test::MockModule->new('pf::Connection::ProfileFactory');
$profile_factory->mock('instantiate', sub { test::profile->new });

my $radius = pf::radius->new;

sub args {
    return {
        mac            => '00:11:22:33:44:55',
        user_name      => 'bob',
        username       => 'bob',
        switch         => { _PostMfaValidation => 'enabled' },
        radius_request => { 'User-Name' => 'bob' },
    };
}

sub is_rejected {
    my ($return, $name) = @_;
    ok(ref($return) eq 'ARRAY' && $return->[0] == $RADIUS::RLM_MODULE_FAIL, "$name: the request is rejected");
    like(ref($return) eq 'ARRAY' ? {@$return[1..$#$return]}->{'Reply-Message'} // '' : '', qr/no-such-mfa/, "$name: the reply names the MFA");
}

for my $action ($Actions::TRIGGER_RADIUS_MFA, $Actions::TRIGGER_PORTAL_MFA) {
    $matched = { source_id => 'test', values => { $action => 'no-such-mfa' } };
    my ($otp, $password, $extra) = (undef, 'secret', undef);
    my $return = eval { $radius->mfa_pre_auth(args(), {}, [], \$extra, \$otp, \$password) };
    is_rejected($return, "pre auth, $action");
}

{
    $matched = { source_id => 'test', values => { $Actions::TRIGGER_RADIUS_MFA => 'no-such-mfa' } };
    my ($otp, $password, $extra) = ('123456', 'secret', undef);
    my $return = eval { $radius->mfa_post_auth(args(), {}, [], 'test', \$extra, \$otp, \$password) };
    is_rejected($return, "post auth");
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
