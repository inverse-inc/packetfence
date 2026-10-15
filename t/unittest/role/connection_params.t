#!/usr/bin/perl

=head1 NAME

connection_params

=head1 DESCRIPTION

Authentication rules evaluated for an 802.1X or MAB request see the switch,
its group, the MAC and the computer name, so a rule condition on
switch_group, switch_id, mac or computer_name can match (#9002).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 12;
use Test::NoWarnings;
use pf::role;
use pf::constants::authentication;
use pf::Authentication::Rule;
use pf::Authentication::Condition;
use pf::Authentication::Action;
use pf::Authentication::Source::NullSource;

my $switch = bless { _id => '192.0.2.10', _group => 'grp9002' }, 'pf::Switch';
my %args = (
    switch    => $switch,
    mac       => '02:44:45:4c:4c:1a',
    user_name => 'jbon',
    node_info => { computername => 'LAPTOP-9002' },
);

is_deeply(
    pf::role::_connection_params(\%args),
    { switch_id => '192.0.2.10', switch_group => 'grp9002', mac => '02:44:45:4c:4c:1a', computer_name => 'LAPTOP-9002' },
    'switch, group, mac and computer name are passed to the rules',
);

is_deeply(
    pf::role::_connection_params({ switch => bless({ _id => '192.0.2.11' }, 'pf::Switch'), mac => '02:00:00:00:00:01', node_info => {} }),
    { switch_id => '192.0.2.11', mac => '02:00:00:00:00:01' },
    'a switch without a group and a node without a computer name add nothing for them',
);

is_deeply(pf::role::_connection_params({}), {}, 'no switch nor node gives no parameters');

my $params = pf::role::makeParams({ %args, connection_type => 0 });
is($params->{switch_group}, 'grp9002', 'makeParams carries the switch group');
is($params->{switch_id}, '192.0.2.10', 'makeParams carries the switch id');

sub rule {
    my ($id, $role, @conditions) = @_;
    return pf::Authentication::Rule->new({
        id         => $id,
        class      => $Rules::AUTH,
        match      => $Rules::ALL,
        conditions => [ map { pf::Authentication::Condition->new($_) } @conditions ],
        actions    => [ pf::Authentication::Action->new({ type => $Actions::SET_ROLE, value => $role }) ],
    });
}

my $source = pf::Authentication::Source::NullSource->new({
    id    => 'null9002',
    rules => [
        rule('by_group', 'gaming', { attribute => 'switch_group', operator => $Conditions::EQUALS, value => 'grp9002' }),
        rule('by_switch', 'voice', { attribute => 'switch_id', operator => $Conditions::EQUALS, value => '192.0.2.99' }),
        rule('catchall', 'default'),
    ],
});

sub matched_rule {
    my ($p) = @_;
    my ($rule) = $source->match({ rule_class => $Rules::AUTH, %$p });
    return $rule ? $rule->id : undef;
}

is(matched_rule($params), 'by_group', 'a switch in the group matches the switch_group rule');

my $other = pf::role::makeParams({ %args, switch => bless({ _id => '192.0.2.10', _group => 'other' }, 'pf::Switch') });
is(matched_rule($other), 'catchall', 'a switch in another group falls through to the catchall');

my $by_id = pf::role::makeParams({ %args, switch => bless({ _id => '192.0.2.99' }, 'pf::Switch') });
is(matched_rule($by_id), 'by_switch', 'a switch_id rule matches the switch');

my %without = %$params;
delete @without{qw(switch_group switch_id mac computer_name)};
is(matched_rule(\%without), 'catchall', 'without the parameters (before the fix) the switch_group rule never matches');

my $condition = pf::Authentication::Condition->new({ attribute => 'computer_name', operator => $Conditions::EQUALS, value => 'LAPTOP-9002' });
ok($condition->matches('computer_name', $params->{computer_name}, $params), 'a computer_name condition sees the node computer name');

my $mac_condition = pf::Authentication::Condition->new({ attribute => 'mac', operator => $Conditions::EQUALS, value => '02:44:45:4c:4c:1a' });
ok($mac_condition->matches('mac', $params->{mac}, $params), 'a mac condition sees the endpoint MAC');

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
