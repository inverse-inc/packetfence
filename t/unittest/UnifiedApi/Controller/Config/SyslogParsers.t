#!/usr/bin/perl

=head1 NAME

Pfdetects

=cut

=head1 DESCRIPTION

unit test for Pfdetects

=cut

use strict;
use warnings;
#
use lib qw(
    /usr/local/pf/lib
);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 16;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/syslog_parsers';

my $base_url = '/api/v1/config/syslog_parser';

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->post_ok($collection_base_url => json => { type => 'ko' })
  ->status_is(422);

$t->post_ok("$collection_base_url/dry_run" => json => { type => 'dhcp' })
  ->status_is(422);

$t->post_ok("$collection_base_url/dry_run" => json => { type => 'regex' })
  ->status_is(422);

my $config = {
    type => 'regex',
    id => 'regex',
    path => '/usr/local/pf/var/log-regex.log',
    rules => [
        {
            regex => 'from: (?P<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?P<dstip>\d{1,3}(\.\d{1,3}){3}), mac: (?P<mac>[a-fA-F0-9]{12})',
            name => 'from to',
            last_if_match => 0,
            actions => [
                { api_method => 'modify_node', api_parameters => '$scrip, $dstip, $mac'},
                { api_method => 'trigger_scan', api_parameters => 'bob, bob'},
            ],
        },
        {
            regex => 'from: (?P<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?P<dstip>\d{1,3}(\.\d{1,3}){3})',
            name => 'from to',
            last_if_match => 1,
            actions => [
                { api_method => 'modify_node', api_parameters => '$scrip, $dstip'},
                { api_method => 'trigger_scan', api_parameters => 'bob, bob'},
            ],
        },
    ],
    lines => [
        "from: 1.2.3.4, to: 1.2.3.5",
    ]
};

$t->post_ok( "$collection_base_url/dry_run" => json => $config )
  ->status_is(200)
  ->json_is(
    {
        items => [
            {
                'matches' => [
                    {
                        'success' => 1,
                        'actions' => [
                            { api_method =>  'modify_node',  api_parameters => [ '1.2.3.4', '1.2.3.5' ] },
                            { api_method => 'trigger_scan', api_parameters => [ 'bob',     'bob' ] }
                        ],
                        'rule' => {
                            'ip_mac_translation' => 'disabled',
                            'rate_limit'         => '0s',
                            'actions'            => [
                                'modify_node: $scrip, $dstip',
                                'trigger_scan: bob, bob'
                            ],
                            'last_if_match' => 'enabled',
                            'regex' =>
    'from: (?P<scrip>\\d{1,3}(\\.\\d{1,3}){3}), to: (?P<dstip>\\d{1,3}(\\.\\d{1,3}){3})',
                            'name' => 'from to'
                        }
                    }
                ],
                'line' => 'from: 1.2.3.4, to: 1.2.3.5'
            }
        ],
        status => 200,
    }
  );

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
