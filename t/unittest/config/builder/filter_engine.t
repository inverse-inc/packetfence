#!/usr/bin/perl

=head1 NAME

filter_engine

=head1 DESCRIPTION

unit test for filter_engine

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

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
use pf::factory::condition;
use pf::condition_parser qw(parse_condition_string);

my $condition_str = 'a == "bob" && b == "bobby"';

my $condition = pf::condition::all->new(
    {
        conditions => [
            pf::condition::key->new({
                key => 'a',
                condition => pf::condition::equals->new({
                    value => 'bob'
                })
            }),
            pf::condition::key->new({
                key => 'b',
                condition => pf::condition::equals->new({
                    value => 'bobby'
                })
            }),
        ]
    },
);

our %LOGICAL_OPS = (
    'AND' => 'pf::condition::all',
    'OR'  => 'pf::condition::any',
);

our %CMP_OP = (
    '=='  => 'pf::condition::equals',
    '!='  => 'pf::condition::not_equals',
    '=~'  => 'pf::condition::regex',
    '!~'  => 'pf::condition::regex_not',
);

sub buildCondition {
    my ($str) = @_;
    my ($ast, $err) = parse_condition_string($str);
    if ($err) {
        die $err->{highlighted_error};
    }
    return _buildCondition($ast);
}

sub _buildCondition {
    my ($ast) = @_;
    if (ref $ast) {
        my ($op, @rest) = @$ast;
        if (exists $LOGICAL_OPS{$op}) {
            if (@rest == 1) {
                return _buildCondition(@rest);
            }

            return $LOGICAL_OPS{$op}->new({conditions => [map { _buildCondition($_) } @rest  ] });
        }

        if (exists $CMP_OP{$op}) {
            my ($key, $val) = @rest;
            my $sub_condition =  $CMP_OP{$op}->new({value => $val}) ;
            return pf::condition::key->new( {key => $key, condition => $sub_condition });
        }
        
        die "op '$op' not defined";
    }
    die "condition '$ast' not defined";
}

is_deeply( buildCondition($condition_str), $condition );
is_deeply(
    buildCondition('a.b != "b"'),
    pf::condition::key->new(
        {
            key       => 'a',
            condition => pf::condition::key->new(
                    {
                        key       => 'b',
                        condition => pf::condition::not_equals->new(
                            {
                                value => 'b'
                            }
                        )
                    }
                )
        }
    )
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

