#!/usr/bin/perl

=head1 NAME

radius

=head1 DESCRIPTION

unit test for radius

=cut

use strict;
use warnings;
#
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);

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
use pf::config::builder::filter_engine::radius;
my $builder = pf::config::builder::filter_engine::radius->new;

{

    my $conf = <<'CONF';
[test]
scopes=preProcess
description=test
status=enabled
top_op=and
condition=connection_type == "Wireless-802.11-EAP"
answer.0=request:NAS-IP-Address = 192.168.0.1
merge_answer=yes

CONF

    my ( $error, $engine ) = build_from_conf( $builder, $conf );
    is( $error, undef, "No Error Found" );
    is_deeply(
        $engine,
        {
            'preProcess' => bless(
                {
                    'filters' => [
                        bless(
                            {
                                'answer' => {
                                    'actions'      => [],
                                    'status'       => 'enabled',
                                    '_rule'        => 'test',
                                    'top_op'       => 'and',
                                    'description'  => 'test',
                                    'params'       => [],
                                    'scopes'       => [ 'preProcess' ],
                                    'merge_answer' => 'yes',
                                    'answers'      => [
                                        {
                                            'tmpl' => bless(
                                                {
                                                    'info' => {},
                                                    'tmpl' =>
                                                      [ 'S', '192.168.0.1' ],
                                                    'text' => '192.168.0.1'
                                                },
                                                'pf::mini_template'
                                            ),
                                            'name' => 'NAS-IP-Address'
                                        }
                                    ],
                                    'condition' =>
                                      'connection_type == "Wireless-802.11-EAP"'
                                },
                                'condition' => bless(
                                    {
                                        'condition' => bless(
                                            {
                                                'value' => 'Wireless-802.11-EAP'
                                            },
                                            'pf::condition::equals'
                                        ),
                                        'key' => 'connection_type'
                                    },
                                    'pf::condition::key'
                                )
                            },
                            'pf::filter'
                        )
                    ]
                },
                'pf::filter_engine'
            )
        }
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

Copyright (C) 2005-2021 Inverse inc.

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
