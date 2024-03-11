#!/usr/bin/perl

=head1 NAME

filter_engine

=head1 DESCRIPTION

unit test for filter_engine

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

use Test::More tests => 19;

#This test will running last
use Test::NoWarnings;
use pf::factory::condition;
use pf::config::builder::filter_engine;
my $builder = pf::config::builder::filter_engine->new;

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
condition=connection_type == "Wireless-802.11-EAP" && not_starts_with(username, "host/")
scopes = RegisteredRole
role = registration
CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
            RegisteredRole => pf::filter_engine->new({
                filters => [
                    pf::filter->new({
                        'condition' => 
                            pf::condition::all->new({
                                conditions => [
                                    pf::condition::key->new(
                                        {
                                            'condition' => bless(
                                                {
                                                    'value' => 'Wireless-802.11-EAP'
                                                },
                                                'pf::condition::equals'
                                            ),
                                            'key' => 'connection_type'
                                        },
                                    ),
                                    pf::condition::not->new({
                                        condition => pf::condition::key->new({
                                            'condition' =>
                                              pf::condition::starts_with
                                              ->new(
                                                {
                                                    'value' =>
                                                      'host/'
                                                },
                                              ),
                                            'key' => 'username'
                                        }),
                                    })
                                  ]
                        }),
                        answer => {
                            status => 'enabled',
                            condition => 'connection_type == "Wireless-802.11-EAP" && not_starts_with(username, "host/")',
                            scopes  => ['RegisteredRole'],
                            _rule   => 'pf_deauth_from_wireless_secure',
                            role    => 'registration',
                            params  => [],
                            answers => [],
                            actions => [ ],
                        },
                    })
                ],
            })
        },
        "Build simple condition filter"
    );
}

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
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
                                    status => 'enabled',
                                    condition => 'bob == "bob"',
                                    scopes  => ['RegisteredRole'],
                                    _rule   => 'pf_deauth_from_wireless_secure',
                                    role    => 'registration',
                                    params  => [],
                                    answers => [],
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
status=enabled
condition=bob.jones == "bob" && bob.jone == "no"
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
                                condition => pf::condition::all->new(
                                    {
                                        'conditions' => [
                                            bless(
                                                {
                                                    key         => 'bob',
                                                    'condition' => bless(
                                                        {
                                                            'condition' =>
                                                              bless(
                                                                {
                                                                    'value' =>
                                                                      'bob'
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
                                            bless(
                                                {
                                                    key         => 'bob',
                                                    'condition' => bless(
                                                        {
                                                            'condition' =>
                                                              bless(
                                                                {
                                                                    'value' => 'no'
                                                                },
'pf::condition::equals'
                                                              ),
                                                            'key' => 'jone'
                                                        },
                                                        'pf::condition::key'
                                                    ),
                                                },
                                                'pf::condition::key'
                                            )
                                        ]
                                    }
                                ),
                                answer => {
                                    status => 'enabled',
                                    condition => 'bob.jones == "bob" && bob.jone == "no"',
                                    scopes    => ['RegisteredRole'],
                                    _rule     => 'pf_deauth_from_wireless_secure',
                                    role    => 'registration',
                                    params  => [],
                                    answers => [],
                                    actions => [
                                        {
                                            api_method => 'modify_node',
                                            api_parameters =>
'mac, $mac, status = unreg, autoreg = no'
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

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
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
                        pf::filter->new({
                            'condition' => pf::condition::key->new({
                                key         => 'bob',
                                'condition' => pf::condition::key->new({
                                    'condition' => bless(
                                        {
                                            'value' => 'bob'
                                        },
                                        'pf::condition::equals'
                                    ),
                                    'key' => 'jones'
                                }),
                            }),
                            answer => {
                                status => 'enabled',
                                condition => 'bob.jones == "bob"',
                                scopes    => ['RegisteredRole'],
                                _rule     => 'pf_deauth_from_wireless_secure',
                                role    => 'registration',
                                params  => [],
                                answers => [],
                                actions => [
                                    {
                                        api_method => 'modify_node',
                                        api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                    },
                                ],
                            },
                        })
                    ],
                }
            )
        },
        "Build simple condition filter with nested key"
    );
}

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
condition=not_date_is_before(bob.jones, "bob")
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
                                'condition' => pf::condition::not->new( {
                                    'condition' => pf::condition::key->new({
                                        key => 'bob',
                                        'condition' => pf::condition::key->new({
                                                        condition => bless({ 'value' => 'bob' }, 'pf::condition::date_before'),
                                                        'key' => 'jones'
                                                    }),
                                    }),
                                }),
                            answer => {
                                    
                                status => 'enabled',
                                condition => 'not_date_is_before(bob.jones, "bob")',
                                scopes    => ['RegisteredRole'],
                                _rule     => 'pf_deauth_from_wireless_secure',
                                role    => 'registration',
                                params  => [],
                                answers => [],
                                actions => [
                                    {
                                        api_method => 'modify_node',
                                        api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                    },
                                ],
                            },
                        })
                    ],
                }
            )
        },
        "Build simple condition filter with nested key"
    );
}

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
condition=contains(bob.jones, "bob")
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
                        pf::filter->new({
                            'condition' => pf::condition::key->new({
                                key         => 'bob',
                                'condition' => pf::condition::key->new({
                                    'condition' => bless(
                                        {
                                            'value' => 'bob'
                                        },
                                        'pf::condition::matches'
                                    ),
                                    'key' => 'jones'
                                }),
                            }),
                            answer => {
                                status => 'enabled',
                                condition => 'contains(bob.jones, "bob")',
                                scopes    => ['RegisteredRole'],
                                _rule     => 'pf_deauth_from_wireless_secure',
                                role    => 'registration',
                                params  => [],
                                answers => [],
                                actions => [
                                    {
                                        api_method => 'modify_node',
                                        api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                    },
                                ],
                            },
                        })
                    ],
                }
            )
        },
        "Build simple condition filter with nested key"
    );
}

{

    my $conf = <<'CONF';
[pf_deauth_from_wireless_secure]
status=enabled
condition=a =~ "^bob"
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
                        pf::filter->new({
                            'condition' => pf::condition::key->new({
                                key         => 'a',
                                'condition' => bless(
                                    {
                                        'value' => '^bob'
                                    },
                                    'pf::condition::regex_not'
                                ),
                            }),
                            answer => {
                                status => 'enabled',
                                condition => 'a =~ "^bob"',
                                scopes    => ['RegisteredRole'],
                                _rule     => 'pf_deauth_from_wireless_secure',
                                role    => 'registration',
                                params  => [],
                                answers => [],
                                actions => [
                                    {
                                        api_method => 'modify_node',
                                        api_parameters => 'mac, $mac, status = unreg, autoreg = no'
                                    },
                                ],
                            },
                        })
                    ],
                }
            )
        },
        "Build simple condition filter with nested key"
    );
}
{

    my $conf = <<'CONF';
[true_always]
status=enabled
condition=true
scopes = preProcess
answer.0=James = bob
CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
            preProcess => pf::filter_engine->new(
                {
                    filters => [
                        pf::filter->new({
                            'condition' => pf::condition::true->new({ }),
                            answer => {
                                status => 'enabled',
                                condition => 'true',
                                scopes    => ['preProcess'],
                                _rule     => 'true_always',
                                params  => [],
                                answers => ['James = bob'],
                                actions => [ ],
                            },
                        })
                    ],
                }
            )
        },
        "Build alway true",
    );
}

{

    my $conf = <<'CONF';
[Bozo]
status=enabled
scopes=returnRadiusAccessAccept
condition=mac == "cc:c0:79:f6:6c:aa" && time_period(time, "wd {Mon Tue Wed Thu Fri} hr {8am-2pm}")
CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
        'returnRadiusAccessAccept' => bless(
            {
                'filters' => [
                    bless(
                        {
                            'answer' => {
                                'params'  => [],
                                'scopes'  => [ 'returnRadiusAccessAccept' ],
                                'actions' => [],
                                'status'  => 'enabled',
                                '_rule'   => 'Bozo',
                                'answers' => [],
                                'condition' =>
'mac == "cc:c0:79:f6:6c:aa" && time_period(time, "wd {Mon Tue Wed Thu Fri} hr {8am-2pm}")'
                            },
                            'condition' => bless(
                                {
                                    'conditions' => [
                                        bless(
                                            {
                                                'condition' => bless(
                                                    {
                                                        'value' =>
                                                          'cc:c0:79:f6:6c:aa'
                                                    },
                                                    'pf::condition::equals'
                                                ),
                                                'key' => 'mac'
                                            },
                                            'pf::condition::key'
                                        ),
                                        bless(
                                                    {
                                                        'value' =>
'wd {Mon Tue Wed Thu Fri} hr {8am-2pm}'
                                                    },
                                                    'pf::condition::time_period'
                                        ),
                                    ]
                                },
                                'pf::condition::all'
                            )
                        },
                        'pf::filter'
                    )
                ]
            },
            'pf::filter_engine'
          )
        },
        "Build condition with pf::condition::time_period"
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

Copyright (C) 2005-2024 Inverse inc.

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

