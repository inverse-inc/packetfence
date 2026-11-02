#!/usr/bin/perl

=head1 NAME

LocalDBSource

=cut

=head1 DESCRIPTION

unit test for LocalDBSource

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 26;
use Test::NoWarnings;
use Test::MockModule;

use pf::authentication;
use pf::Authentication::constants;
use pf::Authentication::Source::LocalDBSource;

my %USERS = (
    admin_user => {
        pid          => 'admin_user',
        access_level => 'SwitchRW',
        category     => 'default',
        unregdate    => '2038-01-01 00:00:00',
        sponsor      => 0,
    },
    plain_user => {
        pid      => 'plain_user',
        category => 'guest',
        sponsor  => 0,
    },
    full_user => {
        pid                => 'full_user',
        access_level       => 'SwitchRW',
        access_duration    => '1D',
        category           => 'default',
        sponsor            => 1,
        trigger_radius_mfa => 'radius_mfa',
        trigger_portal_mfa => 'portal_mfa',
    },
);

my $password_mock = Test::MockModule->new('pf::password');
$password_mock->mock(view => sub { my ($pid) = @_; return $USERS{$pid} });
$password_mock->mock(view_email => sub { return undef });

my $person_mock = Test::MockModule->new('pf::person');
$person_mock->mock(person_view => sub { my ($pid) = @_; return { pid => $pid } });

=head2 admin_rule

=cut

sub admin_rule {
    my ($id, $username) = @_;

    return pf::Authentication::Rule->new({
        id         => $id,
        class      => $Rules::ADMIN,
        match      => $Rules::ALL,
        conditions => [
            pf::Authentication::Condition->new({
                attribute => 'username',
                operator  => $Conditions::EQUALS,
                value     => $username,
            }),
        ],
        actions => [
            pf::Authentication::Action->new({
                type  => $Actions::SET_ACCESS_LEVEL,
                value => 'RuleAccessLevel',
            }),
        ],
    });
}

=head2 make_source

=cut

sub make_source {
    my (%args) = @_;

    my @rules;
    if (my $username = $args{matching_username}) {
        push @rules, admin_rule('switch_login', $username);
    }

    return pf::Authentication::Source::LocalDBSource->new({
        id    => 'local_db',
        rules => \@rules,
        (exists $args{fallback} ? (fallback_to_static_user_attributes => $args{fallback}) : ()),
    });
}

sub admin_params {
    my ($username) = @_;
    return {
        username   => $username,
        rule_class => $Rules::ADMIN,
    };
}

=head2 A matching rule always wins over the stored attributes

=cut

{
    my $source = make_source(matching_username => 'admin_user');
    my ($rule) = $source->match(admin_params('admin_user'), $Actions::SET_ACCESS_LEVEL);
    ok(defined $rule, "the administration rule matched");
    is($rule->id, 'switch_login', "the configured rule is returned, not the fallback");
    is($rule->actions->[0]->value, 'RuleAccessLevel', "the access level comes from the rule");
}

=head2 No matching rule falls back to the access level stored on the user

=cut

{
    my $source = make_source(matching_username => 'somebody_else');
    my ($rule, $ignore_action, $matched) = $source->match(admin_params('admin_user'), $Actions::SET_ACCESS_LEVEL);
    ok(defined $rule, "the fallback provided a rule when no rule matched");
    is($rule->id, 'static_user_attributes', "the fallback rule is returned");
    is($rule->class, $Rules::ADMIN, "the fallback rule is in the requested class");
    is($matched, 'admin_user', "the pid of the local user is returned");
    my ($access_level) = grep { $_->type eq $Actions::SET_ACCESS_LEVEL } @{$rule->actions};
    is($access_level->value, 'SwitchRW', "the access level comes from the password table");
    is(scalar @{$rule->actions}, 1, "only the actions of the requested class are returned");
}

=head2 The fallback can be turned off

=cut

{
    my $source = make_source(matching_username => 'somebody_else', fallback => 0);
    my ($rule) = $source->match(admin_params('admin_user'), $Actions::SET_ACCESS_LEVEL);
    is($rule, undef, "no match when the fallback is disabled");
}

=head2 A source that carries no value at all keeps the fallback

=cut

{
    my $source = make_source(matching_username => 'somebody_else');
    delete $source->{fallback_to_static_user_attributes};
    my ($rule) = $source->match(admin_params('admin_user'), $Actions::SET_ACCESS_LEVEL);
    ok(defined $rule && $rule->id eq 'static_user_attributes', "an unset option is treated as enabled");
}

=head2 The fallback also covers the authentication class

=cut

{
    my $source = make_source();
    my ($rule) = $source->match({ username => 'plain_user', rule_class => $Rules::AUTH }, $Actions::SET_ROLE);
    ok(defined $rule, "the fallback provided a rule for the authentication class");
    my ($role) = grep { $_->type eq $Actions::SET_ROLE } @{$rule->actions};
    is($role->value, 'guest', "the role comes from the category of the password table");
}

=head2 Every action the SQL source builds is carried by the fallback

=cut

{
    my $source = make_source();

    my ($auth_rule) = $source->match({ username => 'full_user', rule_class => $Rules::AUTH });
    my %auth = map { $_->type => $_->value } @{$auth_rule->actions};
    is($auth{$Actions::TRIGGER_RADIUS_MFA}, 'radius_mfa', "the RADIUS MFA trigger is carried over");
    is($auth{$Actions::TRIGGER_PORTAL_MFA}, 'portal_mfa', "the portal MFA trigger is carried over");
    is($auth{$Actions::SET_ACCESS_DURATION}, '1D', "the access duration is carried over");

    my ($admin_rule) = $source->match(admin_params('full_user'));
    my %admin = map { $_->type => $_->value } @{$admin_rule->actions};
    is($admin{$Actions::MARK_AS_SPONSOR}, 1, "the sponsor flag is carried over");
    is($admin{$Actions::SET_ACCESS_LEVEL}, 'SwitchRW', "the access level is carried over");
    ok(!exists $admin{$Actions::TRIGGER_RADIUS_MFA}, "an authentication action stays out of the administration class");
}

=head2 The user is read from the database once per match

=cut

{
    my $reads = 0;
    $password_mock->mock(view => sub { $reads++; return $USERS{$_[0]} });

    my $source = pf::Authentication::Source::LocalDBSource->new({
        id    => 'local_db',
        rules => [ map { admin_rule("no_match_$_", "somebody_else_$_") } 1 .. 3 ],
    });
    $source->match(admin_params('admin_user'), $Actions::SET_ACCESS_LEVEL);
    is($reads, 1, "three rules and the fallback share a single lookup");

    $password_mock->mock(view => sub { return $USERS{$_[0]} });
}

=head2 An administration rule without conditions is worth a warning

=cut

{
    my $source = make_source();

    my $catchall = admin_rule('everyone', 'somebody');
    $catchall->conditions([]);
    like($source->unconditional_admin_rule_warning($catchall), qr/RuleAccessLevel/,
        "a conditionless administration rule is reported with the access level it grants");

    is($source->unconditional_admin_rule_warning(admin_rule('switch_login', 'admin_user')), undef,
        "a rule with a condition is not reported");

    my $network_catchall = pf::Authentication::Rule->new({
        id         => 'catchall',
        class      => $Rules::AUTH,
        match      => $Rules::ALL,
        conditions => [],
        actions    => [ pf::Authentication::Action->new({ type => $Actions::SET_ROLE, value => 'guest' }) ],
    });
    is($source->unconditional_admin_rule_warning($network_catchall), undef,
        "a conditionless authentication rule is left alone");
}

=head2 An unknown user never matches

=cut

{
    my $source = make_source();
    my ($rule) = $source->match(admin_params('unknown_user'), $Actions::SET_ACCESS_LEVEL);
    is($rule, undef, "a user that is not in the password table does not match");
}

=head2 A user without the requested action does not match either

=cut

{
    my $source = make_source();
    my ($rule) = $source->match(admin_params('plain_user'), $Actions::SET_ACCESS_LEVEL);
    is($rule, undef, "a user without an access level does not match an administration request");
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
