#!/usr/bin/perl
=head1 NAME

coding-style.t

=head1 DESCRIPTION

Test validating coding style guidelines.

=cut

use strict;
use warnings;
use diagnostics;

use Test::More;
use Test::NoWarnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use TestUtils qw(get_all_perl_binaries get_all_perl_cgi get_all_perl_modules);

my @files;

# TODO add our javascript to these tests
push(@files, TestUtils::get_all_perl_binaries());
push(@files, TestUtils::get_all_perl_cgi());
push(@files, grep {!m#addons/sourcefire/#}  TestUtils::get_all_perl_modules());

# all files + no warnings
plan tests => scalar @files * 1 + 1;

# lookout for TABS
foreach my $file (@files) {

    open(my $fh, '<', $file) or die "Can't open $file: $!";

    my $tabFound = 0;
    while (<$fh>) {
        if (/\t/) {
            $tabFound = 1;
        }
    }

    # I hate tabs!!
    ok(!$tabFound, "no tab character in $file");
}

# TODO test the tests for coding style but only if they are present
# (since they are not present in build system by default)

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

