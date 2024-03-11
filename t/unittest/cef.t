#!/usr/bin/perl

=head1 NAME

cef

=head1 DESCRIPTION

unit test for cef

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

our (@HEADER_TESTS, @HEADER_EXT, @CEF_MESSAGE_TESTS);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    use pf::version;
    @HEADER_TESTS = (
        {in => "\\", out => "\\\\"},
        {in => "|", out => "\\|"},
        {in => "=", out => "="},
        {in => "Bob = s", out => "Bob = s"},
        {in => "Bob | s", out => "Bob \\| s"},
        {in => "Bob \\ s", out => "Bob \\\\ s"},
    );
    @HEADER_EXT = (
        {in => "\\", out => "\\\\"},
        {in => "|", out => "|"},
        {in => "=", out => "\\="},
        {in => "Bob = s", out => "Bob \\= s"},
        {in => "Bob | s", out => "Bob | s"},
        {in => "Bob \\ s", out => "Bob \\\\ s"},
        {in => "Bob \n s", out => "Bob \\n s"},
        {in => "Bob \r s", out => "Bob \\r s"},
    );
    my $version = pf::version::version_get_current();

    @CEF_MESSAGE_TESTS = (
        {
            new => {
                deviceEventClassId => 'ClassId',
                severity           => 0,
            },
            in => ['Name'],
            out => "CEF:0|Inverse|PacketFence|$version|ClassId|Name|0|",
        },
        {
            new => {
                deviceEventClassId => 'Class |Id',
                severity           => 0,
            },
            in => ['Name='],
            out => "CEF:0|Inverse|PacketFence|$version|Class \\|Id|Name=|0|",
        },
        {
            new => {
                deviceEventClassId => 'Class \\Id',
                severity           => 0,
            },
            in => ['Name'],
            out => "CEF:0|Inverse|PacketFence|$version|Class \\\\Id|Name|0|",
        },
        {
            new => {
                deviceEventClassId => 'ClassId',
                severity           => 0,
            },
            in => ['Name', {bob => 'bob'}],
            out => "CEF:0|Inverse|PacketFence|$version|ClassId|Name|0|bob=bob",
        },
    );
}

use Test::More tests => 1 + scalar @HEADER_TESTS + scalar @HEADER_EXT + scalar @CEF_MESSAGE_TESTS;

#This test will running last
use Test::NoWarnings;
use pf::cef;

#This is the first test

for my $test (@HEADER_TESTS) {
    is(pf::cef::format_header($test->{in}), $test->{out}, "format($test->{in}) = $test->{out})");
}

for my $test (@HEADER_EXT) {
    is(pf::cef::format_ext($test->{in}), $test->{out}, "format($test->{in}) = $test->{out})");
}


for my $test (@CEF_MESSAGE_TESTS) {
    my $new = $test->{new};
    my $cef = pf::cef->new($new);
    is( $cef->message(@{$test->{in}}), $test->{out}, "CEF is $test->{out}" );
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

