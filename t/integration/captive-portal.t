#!/usr/bin/perl
=head1 NAME

integration/captive-portal.t

=head1 DESCRIPTION

Tests that are more end-to-end and require that Apache runs.

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;
use Test::WWW::Mechanize;

# These should always work
my @clean_URLs = qw(
    access
    aup
    authenticate
    captive-portal
    enabler
    release
    signup
    status
);

my $http_tests = Test::WWW::Mechanize->new;
foreach my $url (@clean_URLs) {
    $http_tests->get_ok( "http://localhost/$url" );
    $http_tests->get_ok( "https://localhost/$url" );
}

# TODO expand the tests
# title checks
# html lint
# poking at the content

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

