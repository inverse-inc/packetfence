#!/usr/bin/perl

=head1 NAME

LDAPSource

=cut

=head1 DESCRIPTION

unit test for LDAPSource

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

our (@CACHEABLE_RULES, @NON_CACHEABLE_RULES);

use pf::authentication;

BEGIN {

    @CACHEABLE_RULES = (

        pf::Authentication::Rule->new(
            {
                id         => "No conditions is cachable",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [],
            }
        ),

        pf::Authentication::Rule->new(
            {
                id         => "Non date related is cachable",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::STARTS,
                            value     => 'bob',
                        }
                    )
                ],
            }
        )
    );

    @NON_CACHEABLE_RULES = (

        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IN_TIME_PERIOD then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IN_TIME_PERIOD,
                            value     => time,
                        }
                    )
                ],
            }
        ),
        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IS_BEFORE then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IS_BEFORE,
                            value     => time,
                        }
                    )
                ],
            }
        ),
        pf::Authentication::Rule->new(
            {
                id         => "If one condition is a IS_AFTER then fail",
                class      => $Rules::AUTH,
                match      => $Rules::ANY,
                conditions => [
                    pf::Authentication::Condition->new(
                        {
                            attribute => 'bob',
                            operator  => $Conditions::IS_AFTER,
                            value     => time,
                        }
                    )
                ],
            }
        ),

    ),

}

use Test::More tests => 5 + 2 * ( scalar @CACHEABLE_RULES + scalar @NON_CACHEABLE_RULES);

#This test will running last
use Test::NoWarnings;

my $source_id = 'LDAPCACHEMATCH';

my $source = getAuthenticationSource($source_id);

ok($source, "Got source id $source_id");

BAIL_OUT("Cannot get $source_id") unless $source;

for my $rule (@CACHEABLE_RULES) {
    ok($source->is_rule_cacheable($rule), $rule->{id});
}

for my $rule (@NON_CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), $rule->{id});
}
ok(!$source->is_rule_cacheable(undef), "undef is always uncacheable");

$source_id = 'LDAPCACHEMATCH_OFF';

$source = getAuthenticationSource($source_id);

ok($source, "Got source id $source_id");

BAIL_OUT("Cannot get $source_id") unless $source;

for my $rule (@CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), "Cache is disabled no rule can be cached : " . $rule->{id});
}

for my $rule (@NON_CACHEABLE_RULES) {
    ok(!$source->is_rule_cacheable($rule), "Cache is disabled no rule can be cached : " . $rule->{id});
}

ok(!$source->is_rule_cacheable(undef), "undef is always uncacheable");

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

1;

