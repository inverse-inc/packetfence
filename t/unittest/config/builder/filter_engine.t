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

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::factory::condition;
use pf::config::builder::filter_engine;
my $builder = pf::config::builder::filter_engine->new;

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
condition=bob == "bob"
scopes = RegisteredRole
action.0=modify_node: mac, $mac, status = unreg, autoreg = no
role = registration
CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
            RegisteredRole => pf::filter_engine->new(
                {
                    filters => [
                        pf::filter->new(
                            {
                                'condition' => bless(
                                    {
                                        'condition' => bless(
                                            {
                                                'value' => 'bob'
                                            },
                                            'pf::condition::equals'
                                        ),
                                        'key' => 'bob'
                                    },
                                    'pf::condition::key'
                                ),
                                answer => {
                                    condition => 'bob == "bob"',
                                    scopes  => ['RegisteredRole'],
                                    id      => 'pf_deauth_from_wireless_secure',
                                    role    => 'registration',
                                    actions => [
                                        {
                                            api_method => 'modify_node',
                                            api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                        },
                                    ],
                                },
                            }
                        )
                    ],
                }
            )
        },
        "Build simple condition filter"
    );
}

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
condition=bob.jones == "bob"
scopes = RegisteredRole
action.0=modify_node: mac, $mac, status = unreg, autoreg = no
role = registration
CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
            RegisteredRole => pf::filter_engine->new(
                {
                    filters => [
                        pf::filter->new(
                            {
                                'condition' => bless(
                                {
                                    key => 'bob',
                                    'condition' => bless(
                                        {
                                            'condition' => bless(
                                                {
                                                    'value' => 'bob'
                                                },
                                                'pf::condition::equals'
                                            ),
                                            'key' => 'jones'
                                        },
                                        'pf::condition::key'
                                    ),
                                },
                                'pf::condition::key'
                                ),
                                answer => {
                                    condition => 'bob.jones == "bob"',
                                    scopes  => ['RegisteredRole'],
                                    id      => 'pf_deauth_from_wireless_secure',
                                    role    => 'registration',
                                    actions => [
                                        {
                                            api_method => 'modify_node',
                                            api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                        },
                                    ],
                                },
                            }
                        )
                    ],
                }
            )
        },
        "Build simple condition filter with nested key"
    );
}

sub build_from_conf {
    my ($builder, $conf) = @_;
    my $ini = pf::IniFiles->new(-file => \$conf);
    return $builder->build($ini);
}


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

