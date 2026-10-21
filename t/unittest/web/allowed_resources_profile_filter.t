#!/usr/bin/perl

=head1 NAME

allowed_resources_profile_filter

=head1 DESCRIPTION

The regex built from the URI filters of the connection profiles follows the
changes of the filters, and an invalid filter is refused or doesn't break it

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 13;

#This test will running last
use Test::NoWarnings;
use pf::web::constants;
use pf::validation::profile_filters;

my @filters;
{
    no warnings qw(redefine once);
    *WEB::_clean_urls_match_filter = sub { @filters };
}

@filters = ();
is(WEB::allowed_resources_profile_filter(), undef, 'no regex without URI filter');

@filters = ('/guest', '/billing/');
my $regex = WEB::allowed_resources_profile_filter();
ok('/guest' =~ $regex, 'a URI filter matches its path');
ok('/guest/x' !~ $regex, 'a URI filter without a trailing / is anchored at the end');
ok('/billing/pay' =~ $regex, 'a URI filter with a trailing / matches the paths under it');

@filters = ('/guest', '/billing/', '/new');
$regex = WEB::allowed_resources_profile_filter();
ok('/new' =~ $regex, 'a new URI filter is applied without reloading the module');

@filters = ('/guest', '/billing/', '/new', '/broken(');
my $kept = WEB::allowed_resources_profile_filter();
ok(defined $kept && '/new' =~ $kept, 'an invalid URI filter keeps the previous regex');
ok(WEB::allowed_resources_profile_filter() == $kept, 'and so do the next calls');

@filters = ('/fixed');
ok('/fixed' =~ WEB::allowed_resources_profile_filter(), 'the regex follows the filters once they are fixed');

my $validator = pf::validation::profile_filters->new;
my ($rc, $message) = $validator->validate('uri:/guest');
ok($rc, 'a valid URI filter is accepted');
($rc, $message) = $validator->validate('uri:/guest(');
ok(!$rc, 'a URI filter that is not a valid regex is refused');
like($message // '', qr/'\/guest\(' is an invalid uri filter/, 'with the reason');
ok(($validator->validate('uri:/portal/.*\.html'))[0], 'a URI filter using a regex is accepted');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
