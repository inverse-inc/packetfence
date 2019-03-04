#!/usr/bin/perl

=head1 NAME

pod.t

=head1 DESCRIPTION

POD documentation validation

=cut

use strict;
use warnings;
use diagnostics;

use Test::More;
use Test::NoWarnings;
use Test::Pod;

BEGIN {
    use lib qw(/usr/local/pf/lib);
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use TestUtils qw(get_all_perl_binaries get_all_perl_cgi get_all_perl_modules);

my @files;
push(@files, TestUtils::get_all_perl_binaries());
push(@files, TestUtils::get_all_perl_cgi());
push(@files, TestUtils::get_all_perl_modules());
my @pf_general_pod = qw(NAME COPYRIGHT);

# all files + no warnings
plan tests => scalar @files * ((scalar @pf_general_pod) + 1  )  + 1;

foreach my $currentFile (@files) {
    my $shortname = $1 if ($currentFile =~ m'^/usr/local/pf/(.+)$');
    pod_file_ok($currentFile, "${shortname}'s POD is valid");
}

# PacketFence module POD
# for now NAME, COPYRIGHT
# TODO expect NAME, SYNOPSIS, DESCRIPTION, AUTHOR, COPYRIGHT, LICENSE
# TODO port to perl module: http://search.cpan.org/~mkutter/Test-Pod-Content-0.0.5/
foreach my $currentFile (@files) {
    my $shortname = $1 if ($currentFile =~ m'^/usr/local/pf/(.+)$');

    # TODO extract in a method if I re-use

    # basically it extracts <name> out of a perl file POD's =head* <name>
    # "perl -l00n" comes from the POD section of the camel book, not so sure what it does
    my $cmd = "cat $currentFile | perl -l00n -e 'print \"\$1\\n\" if /^=head\\d\\s+(\\w+)/;'";
    my $result = `$cmd`;
    $result =~ s/\c@//g; # I had these weird control-chars in my string
    my @pod_headers = split("\n", $result);
    chomp @pod_headers; # discards last element if it's a newline

    foreach my $pf_expected_header (@pf_general_pod) {
        # TODO performance could be improved if I qr// the regexp (see perlop)
        ok(grep(/^$pf_expected_header$/, @pod_headers), "$shortname POD doc section $pf_expected_header exists");
    }
}

# TODO switch module POD
# expect bugs and limitations, status, ...

# TODO CLI perl
# expect USAGE

# TODO PacketFence core
# # expect SUBROUTINES

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

