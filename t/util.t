#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
	use lib qw(/usr/local/pf/t);
	use setup_test_config;
}


use pf::constants qw($TRUE $FALSE);

our (
    @INVALID_DATES,
    @STRIP_FILENAME_FROM_EXCEPTIONS_TESTS,
    @NORMALIZE_TIME_TESTS,
    @EXPAND_CSV_TESTS,
    @VALID_UNREG_DATE_TESTS,
    @MAC2DEC,
    @NODE_ID_TESTS,
    @UNPRETTY_BANDWIDTH_TESTS,
);

BEGIN {
    no warnings 'portable';
    @NODE_ID_TESTS = (
        {
            mac => "00:00:00:00:00:00",
            node_id => (0 << 48),
        },
        {
            mac => "aa:00:00:00:00:ff",
            node_id => (0 << 48) | 0xaa00000000ff,
        }
    );
    @MAC2DEC = (
        {
            in  => "aa:bb:cc:dd:ee:ff",
            out => "170.187.204.221.238.255",
            msg => "mac2dec aa:bb:cc:dd:ee:ff -> 170.187.204.221.238.255",
        },
        {
            in  => "11:22:33:44:55:66",
            out => "17.34.51.68.85.102",
            msg => "mac2dec 11:22:33:44:55:66 -> 17.34.51.68.85.102",
        },
        {
            in  => "ff:ee:dd:cc:bb:aa",
            out => "255.238.221.204.187.170",
            msg => "mac2dec ff:ee:dd:cc:bb:aa -> 255.238.221.204.187.170",
        },
    );

    @INVALID_DATES = (
        {
            in  => undef,
            msg => "undef date",
        },
        {
            in  => "garbage",
            msg => "Invalid date",
        },
        {
            in  => "2017",
            msg => "invalid date year only",
        },
        {
            in  => "2017-02",
            msg => "invalid date year month only",
        },
    );

    @STRIP_FILENAME_FROM_EXCEPTIONS_TESTS = (
        {
            in  => undef,
            out => undef,
            msg => "Undef returns undef",
        },
        {
            in  => '',
            out => '',
            msg => "empty string"
        },
        {
            in  => 'Blah blah blah at -e line 1.',
            out => 'Blah blah blah',
            msg => "simple die string"
        },
        {
            in  => 'Blah at blah and at blah at -e line 1.',
            out => 'Blah at blah and at blah',
            msg => "With multiple at in exception string"
        },
        {
            in  => 'Blah at blah and at blah',
            out => 'Blah at blah and at blah',
            msg => "Nothing needs to be stripped"
        },
        {
            in  => "\nBlah at blah \nalso blah at -e line 1.\n",
            out => "\nBlah at blah \nalso blah\n",
            msg => "Exception with multiple lines"
        },
    );

    @NORMALIZE_TIME_TESTS = (
        {
            in  => undef,
            out => undef,
            msg => "undef normalize attempt",
        },
        {
            in  => "5Z",
            out => 0,
            msg => "illegal normalize attempt",
        },
        {
            in  => "5",
            out => 5,
            msg =>
              "normalizing w/o a time resolution specified (seconds assumed)"
        },
        {
            in => "2s",
            out => 2 * 1,
            msg => "normalizing seconds"
        },
        {
            in => "2m",
            out => 2 * 60,
            msg => "normalizing minutes"
        },
        {
            in => "2h",
            out => 2 * 60 * 60,
            msg => "normalizing hours"
        },
        {
            in => "2D",
            out => 2 * 24 * 60 * 60,
            msg => "normalizing days"
        },
        {
            in => "2W",
            out => 2 * 7 * 24 * 60 * 60,
            msg => "normalizing weeks"
        },
        {
            in  => "2M",
            out => 2 * 30 * 24 * 60 * 60,
            msg => "normalizing months"
        },
        {
            in  => "2Y",
            out => 2 * 365 * 24 * 60 * 60,
            msg => "normalizing years"
        },
    );

    @EXPAND_CSV_TESTS = (
        {
            in  => '',
            out => [],
            msg => "empty string",
        },
        {
            in  => [],
            out => [],
            msg => "empty array",
        },
        {
            in  => undef,
            out => [],
            msg => "undef"
        },
        {
            in  => "a,b,c",
            out => [qw(a b c)],
            msg => "simply list",
        },
        {
            in  => [qw(a b c)],
            out => [qw(a b c)],
            msg => "simply array",
        },
        {
            in  => "a , b , c",
            out => [qw(a b c)],
            msg => "simply list with spaces",
        },
        {
            in  => [qw(a b ), "c,d"],
            out => [qw(a b c d)],
            msg => "list with in a list ",
        },
    );

    @VALID_UNREG_DATE_TESTS = (
        {
            in  => '0-01-01',
            out => $TRUE,
            msg => "Allow a zero year 0-01-01"
        },
        {
            in  => '0-01-41',
            out => $FALSE,
            msg => "Invalid month day with zero year 0-01-41"
        },
        {
            in  => '0000-01-31',
            out => $TRUE,
            msg => "Allow a zero year 0000-01-31"
        },
        {
            in  => '0000-01-41',
            out => $FALSE,
            msg => "Invalid month day with zero year 0000-01-41"
        },
        {
            in  => '0001-01-01',
            out => $FALSE,
            msg => "0001-01-01"
        },
        {
            in  => '1970-01-01',
            out => $TRUE,
            msg => "valid date 1970-01-01",
        },
        {
            in  => '2037-12-31',
            out => $TRUE,
            msg => "valid date 2037-12-31",
        },
        {
            in  => '2038-01-01',
            out => $TRUE,
            msg => "valid date 2038-01-01"
        },
        {
            in  => '0000-00-00',
            out => $TRUE,
            msg => "valid date 0000-00-00",
        },
    );
    @UNPRETTY_BANDWIDTH_TESTS = (
        {
            in => [qw(10240)],
            out => '10240',
            msg => 'A simple number stays the same',
        },
        {
            in => [qw(10KB)],
            out => '10240',
            msg => '10 kilobytes',
        },
        {
            in => [qw(10kb)],
            out => '10240',
            msg => '10 kilobytes lc',
        },
        {
            in => [qw(10MB)],
            out => 10 * 1024 * 1024,
            msg => '10 megabytes',
        },
        {
            in => [qw(10GB)],
            out => 10 * 1024 * 1024 * 1024,
            msg => '10 gigabytes',
        },
        {
            in => [qw(10TB)],
            out => 10 * 1024 * 1024 * 1024 * 1024,
            msg => '10 terabytes',
        },
        {
            in => [qw(10PB)],
            out => 10 * 1024 * 1024 * 1024 * 1024 * 1024,
            msg => '10 petabytes',
        },
        {
            in => [qw(10 KB)],
            out => '10240',
            msg => '10 kilobytes 2 args',
        },
        {
            in => [qw(10 kb)],
            out => '10240',
            msg => '10 kilobytes 2 args - lc',
        },
        {
            in => [qw(10 MB)],
            out => 10 * 1024 *1024,
            msg => '10 megabytes 2 args',
        },
        {
            in => [qw(10 GB)],
            out => 10 * 1024 * 1024 * 1024,
            msg => '10 gigabytes 2 args',
        },
        {
            in => [qw(10 TB)],
            out => 10 * 1024 * 1024 * 1024 * 1024,
            msg => '10 terabytes 2 args',
        },
        {
            in => [qw(10 PB)],
            out => 10 * 1024 * 1024 * 1024 * 1024 * 1024,
            msg => '10 petabytes 2 args',
        },
    );
}

use Test::More;
use Test::NoWarnings;

BEGIN {
    plan tests => 47 +
      ((scalar @NODE_ID_TESTS) * 3) +
      scalar @STRIP_FILENAME_FROM_EXCEPTIONS_TESTS +
      scalar @INVALID_DATES +
      scalar @NORMALIZE_TIME_TESTS +
      scalar @EXPAND_CSV_TESTS +
      scalar @VALID_UNREG_DATE_TESTS +
      scalar @UNPRETTY_BANDWIDTH_TESTS +
      scalar @MAC2DEC;
}

BEGIN {
    use_ok('pf::util');
    use_ok('pf::config::util');
    use_ok('pf::util::apache');
}

my @info = ("lzammit","turkeycorp");
is_deeply(\@info, [strip_username('lzammit@turkeycorp')],
  'Splitting username with @ works');
is_deeply(\@info, [strip_username('lzammit%turkeycorp')],
  'Splitting username with % works');
is_deeply(\@info, [strip_username('turkeycorp\\lzammit')],
  'Splitting username with middle backslash works');
is_deeply(\@info, [strip_username('\\\\turkeycorp\\lzammit')],
  'Splitting username with double prefix backslash and middle backslash works');
is_deeply('lzammit', strip_username('lzammit'),
  'Splitting username without realm returns username');
is_deeply("lzammit&turkeycorp", strip_username('lzammit&turkeycorp'),
  'Splitting username with invalid realm separator returns username');
is_deeply(undef, strip_username(undef),
  'Splitting username undef returns undef');

my @info2 = ("lzammit", "zammitcorp.com");
is_deeply(\@info2, [strip_username('lzammit@zammitcorp.com')],
          'Splitting email address with @ works');

# clean_mac
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");
is(clean_mac("aa:bb:cc:dd:ee:ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx:xx:xx:xx:xx:xx");
is(clean_mac("aa-bb-cc-dd-ee-ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
is(clean_mac("AA-BB-CC-DD-EE-FF"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
is(clean_mac("aabb-ccdd-eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx-xxxx-xxxx");
is(clean_mac("aabb.ccdd.eeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxx.xxxx.xxxx");
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");
is(clean_mac("abc"), "0", "clean invalid MAC address of the form xxx");
is(clean_mac(""), "0", "clean empty MAC address");
is(clean_mac(undef), "0", "clean undefined MAC address");

# valid_mac
ok(valid_mac("aa:bb:cc:dd:ee:ff"), "validate MAC address of the form xx:xx:xx:xx:xx:xx");
ok(valid_mac("aa-bb-cc-dd-ee-ff"), "validate MAC address of the form xx-xx-xx-xx-xx-xx");
ok(valid_mac("aabb-ccdd-eeff"), "validate MAC address of the form xxxx-xxxx-xxxx");
ok(valid_mac("aabb.ccdd.eeff"), "validate MAC address of the form xxxx.xxxx.xxxx");
ok(valid_mac("aabbccddeeff"), "validate MAC address of the form xxxxxxxxxxxx");
ok(!valid_mac("abc"), "invalidate MAC address of the form xxx");
ok(!valid_mac(""), "invalidate empty MAC address");
ok(!valid_mac(undef), "invalidate undefined MAC address");

# oid2mac / mac2oid
is( oid2mac('240.77.162.203.217.197'), 'f0:4d:a2:cb:d9:c5', "oid2mac legit conversion" );
# this throws warnings
# is( oid2mac(), undef, "oid2mac return undef on failure" );
is( mac2oid('f0:4d:a2:cb:d9:c5'), '240.77.162.203.217.197', "mac2oid legit conversion" );
# this throws warnings
# is( mac2oid(), undef, "mac2oid return undef on failure" );

# regression test for get_translatable_time
is_deeply(
    [ get_translatable_time("3D") ],
    ["day", "days", 3],
    "able to translate new format with capital date modifiers"
);

is( format_mac_as_cisco('f0:4d:a2:cb:d9:c5'), 'f04d.a2cb.d9c5', 'format_mac_as_cisco legit conversion');
is( format_mac_as_cisco(), undef, 'format_mac_as_cisco return undef on failure');

# pf::util::apache

# url_parser
my @return = pf::util::apache::url_parser('http://packetfence.org/tests/conficker.html');
is_deeply(\@return,
    [ 'http\:\/\/packetfence\.org', 'http', 'packetfence\.org', '\/tests\/conficker\.html' ],
    "Parsing a standard URL"
);

@return = pf::util::apache::url_parser('HTTPS://www.inverse.ca/');
is_deeply(\@return,
    [ 'https\:\/\/www\.inverse\.ca', 'https', 'www\.inverse\.ca', '\/' ],
    "Parsing an uppercase HTTPS URL with no query"
);

@return = pf::util::apache::url_parser('http://www.google.co.uk');
is_deeply(\@return,
    [ 'http\:\/\/www\.google\.co\.uk', 'http', 'www\.google\.co\.uk', '\/' ],
    'regression test for issue 1368: accept domains without ending slash'
);

@return = pf::util::apache::url_parser('invalid://url$.com');
ok(!@return, "Passed invalid URL expecting undef");

# is_in_list
ok(is_in_list("sms","sms,email"), "is_in_list positive");
ok(!is_in_list("sms","email"), "is_in_list negative");
ok(!is_in_list("sms",""), "is_in_list empty list");
ok(is_in_list("sms","sms, email"), "is_in_list positive with spaces");

{
    for my $test (@NORMALIZE_TIME_TESTS) {
        is(normalize_time($test->{in}), $test->{out}, $test->{msg});
    }
}

{
    foreach my $test (@EXPAND_CSV_TESTS) {
        is_deeply( [ expand_csv( $test->{in} ) ], $test->{out}, "expand_csv $test->{msg}" );
    }
}

{
    for my $test (@INVALID_DATES) {
        ok(!valid_date($test->{in}), $test->{msg});
    }
}

# TODO add more tests, we should test:
#  - all methods ;)

for my $test (@STRIP_FILENAME_FROM_EXCEPTIONS_TESTS) {
    is (
        strip_filename_from_exceptions($test->{in}),
        $test->{out},
        $test->{msg}
    )
}

for my $test (@VALID_UNREG_DATE_TESTS) {
    is (
        validate_unregdate($test->{in}),
        $test->{out},
        $test->{msg}
    )
}

for my $test (@MAC2DEC) {
    is (
        mac2dec($test->{in}),
        $test->{out},
        $test->{msg}
    )
}


{

    for my $test (@NODE_ID_TESTS) {
        my $node_id = $test->{node_id};
        my $mac = $test->{mac};
        is(
            make_node_id(0, $mac),
            $node_id,
            "Convert tenant_id mac (0, $mac) to a node_id ($node_id)"
        );
        
        my ($expect_tenant_id, $expected_mac) = split_node_id($node_id);
        is($expect_tenant_id, 0, "split_node_id($node_id) tenant_id");
        is($expected_mac, $mac, "split_node_id($node_id) mac");
    }

}

{

    for my $test (@UNPRETTY_BANDWIDTH_TESTS) {
        is(
            unpretty_bandwidth(@{$test->{in}}),
            $test->{out},
            $test->{msg},
        );
    }
}

{
    is(extract("j.domain.com", "(.*?)\.domain.com", '$1'), 'j', 'Extract');
    is(extract('[inverse-test@staff.it.acme.edu](mailto:inverse-test@staff.it.acme.edu)','@(\w+)','$1.VLAN'), "staff.VLAN")
}

{
    ok(starts_with("dog", "do"), "starts_with");
    ok(!starts_with("cat", "do"), "starts_with");
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

