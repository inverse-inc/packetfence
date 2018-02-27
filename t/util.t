#!/usr/bin/perl -w

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

our (
    @INVALID_DATES,
    @STRIP_FILENAME_FROM_EXCEPTIONS_TESTS,
    @NORMALIZE_TIME_TESTS
);

BEGIN {
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
}

use Test::More;
use Test::NoWarnings;

BEGIN {
    plan tests => 41 + scalar @STRIP_FILENAME_FROM_EXCEPTIONS_TESTS + scalar @INVALID_DATES + scalar @NORMALIZE_TIME_TESTS;
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

# clean_mac
is(clean_mac("aabbccddeeff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xxxxxxxxxxxx");
is(clean_mac("aa:bb:cc:dd:ee:ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx:xx:xx:xx:xx:xx");
is(clean_mac("aa-bb-cc-dd-ee-ff"), "aa:bb:cc:dd:ee:ff", "clean MAC address of the form xx-xx-xx-xx-xx-xx");
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

