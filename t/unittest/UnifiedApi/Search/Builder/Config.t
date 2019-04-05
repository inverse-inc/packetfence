#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Search::Builder::Config

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

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Search::Builder::Config;

my $sb = pf::UnifiedApi::Search::Builder::Config->new();

{
    my @f = qw(mac id);

    my %search_info = (
        fields => \@f,
        query => {
            op => 'equals',
            field => 'mac',
            value => "00:11:22:33:44:55",
        },
    );

    is_deeply(
        $sb->make_condition( \%search_info ),
        pf::condition::key->new(
            {
                key       => 'mac',
                condition => pf::condition::equals->new(
                    { value => "00:11:22:33:44:55" }
                ),
            }
        ),
        'Build a simple condition'
    );

    is_deeply(
        $sb->make_condition( {query => undef} ),
        pf::condition::true->new(),
        'No query'
    );

    is_deeply(
        $sb->make_condition(
            {
                query => {
                    op     => 'and',
                    values => [
                        { op => 'not_equals', field => 'mac', value => '11' },
                        { op => 'not_equals', field => 'mac', value => '12' }
                    ]
                }
            }
          ),
        pf::condition::all->new({
            conditions => [
                pf::condition::key->new({ key => 'mac', condition => pf::condition::not_equals->new({value => '11'}) }),
                pf::condition::key->new({ key => 'mac', condition => pf::condition::not_equals->new({value => '12'}) }),
            ],
        }),
        'Logical ops'
    );

    is_deeply(
        $sb->make_condition(
            {
                query => {
                    op     => 'and',
                    values => [
                        { op => 'not_equals', field => 'mac', value => '11' },
                    ]
                }
            }
        ),
        pf::condition::key->new(
            {
                key       => 'mac',
                condition => pf::condition::not_equals->new( { value => '11' } )
            }
        ),
        'Single sub'
    );

}

exit 0;

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
