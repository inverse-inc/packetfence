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

use Test::More tests => 6;
#This test will running last
use Test::NoWarnings;

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
            actions => ['modify_node: $scrip, $dstip, $mac', 'violation_log: bob, bob'],
        },
        {
            regex => qr/from: (?<scrip>\d{1,3}(\.\d{1,3}){3}), to: (?<dstip>\d{1,3}(\.\d{1,3}){3})/,
            name => 'from to',
            last_if_match => 1,
            actions => ['modify_node: $scrip, $dstip', 'violation_log: bob, bob'],
        },
    ],
};

my $parser = pf::detect::parser::regex->new($config);

is($parser->parse("from: 1.2.3.4, to: 1.2.3"), undef, "Invalid line");

my $matches = $parser->matchLine("from: 1.2.3.4, to: 1.2.3.5");

is_deeply(
    $matches,
    [
        {
            rule => $config->{rules}[1],
            actions => [['modify_node', ['1.2.3.4', '1.2.3.5']], ['violation_log', ['bob', 'bob']]],
        }
    ],
    "Match one rule"
);

$matches = $parser->matchLine("from: 1.2.3.4, to: 1.2.3.5, mac: aabbccddeeff");

is_deeply(
    $matches,
    [
        {
            rule => $config->{rules}[0],
            actions => [['modify_node', ['1.2.3.4', '1.2.3.5', 'aa:bb:cc:dd:ee:ff']], ['violation_log', ['bob', 'bob']]],
        },
        {
            rule => $config->{rules}[1],
            actions => [['modify_node', ['1.2.3.4', '1.2.3.5']], ['violation_log', ['bob', 'bob']]],
        }
    ],
    "Match two rules"
);

my $result = $parser->parse("from: 1.2.3.4, to: 1.2.3.5");

is($result, "0", "Parsing is good");


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
