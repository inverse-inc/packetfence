=head1 NAME

regex

=cut

=head1 DESCRIPTION

unit test for regex

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

use Test::More tests => 4;
#This test will running last
use Test::NoWarnings;
use Test::MockObject::Extends;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use_ok('pf::detect::parser::regex');

my $config = {
    type => 'regex',
    id => 'regex',
    path => '/usr/local/pf/var/log-regex.log',
    rules => [
        {
            regex => qr/from: (?<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?<dstip>\d{1,3}(\.\d{1,3}){3}), mac: (?<mac>[a-fA-F0-9]{12})/,
            name => 'from to',
            last_if_match => 0,
            actions => ['modify_node: $scrip, $dstip, $mac', 'security_event_log: bob, bob'],
        },
        {
            regex => qr/from: (?<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?<dstip>\d{1,3}(\.\d{1,3}){3})/,
            name => 'from to',
            last_if_match => 1,
            actions => ['modify_node: $scrip, $dstip', 'security_event_log: bob, bob'],
        },
    ],
};

my $parser = pf::detect::parser::regex->new($config);

my $matches = $parser->matchLine("from: 1.2.3.4, to: 1.2.3.5");

is_deeply(
    $matches,
    [
        {
            'success' => 1,
            rule => $config->{rules}[1],
            actions => [
                { api_method => 'modify_node', api_parameters => ['1.2.3.4', '1.2.3.5']},
                { api_method => 'security_event_log', api_parameters => ['bob', 'bob']}
            ],
        }
    ],
    "Match one rule"
);

$matches = $parser->matchLine("from: 1.2.3.4, to: 1.2.3.5, mac: aabbccddeeff");

is_deeply(
    $matches,
    [
        {
            'success' => 1,
            rule => $config->{rules}[0],
            actions => [
                { api_method => 'modify_node', api_parameters => ['1.2.3.4', '1.2.3.5', 'aa:bb:cc:dd:ee:ff']}, 
                { api_method => 'security_event_log', api_parameters => ['bob', 'bob']}
            ],
        },
        {
            'success' => 1,
            rule => $config->{rules}[1],
            actions => [
                {api_method => 'modify_node', api_parameters =>['1.2.3.4', '1.2.3.5']},
                {api_method => 'security_event_log', api_parameters => ['bob', 'bob']}
            ],
        }
    ],
    "Match two rules"
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
