#!/usr/bin/perl

=head1 NAME

profile

=head1 DESCRIPTION

unit test for pf::filter_engine::profile: a connection profile whose filters
can't be built is skipped, the other profiles still work

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 4;
use Test::NoWarnings;
use pf::filter_engine::profile;

my $engine = eval {
    pf::filter_engine::profile->new({
        ordered_ids => [qw(broken valid default)],
        config => {
            broken => { filter => [], advanced_filter => 'date_is_before(node_info.regdate, "garbage")' },
            valid  => { filter => [], advanced_filter => 'date_is_before(node_info.regdate, "2030-01-01")' },
            default => {},
        },
    })
};
ok($engine, 'the engine is built with a profile whose advanced filter is invalid');

is($engine && $engine->match_first({ node_info => { regdate => '2015-11-27 13:49:42' } }), 'valid', 'the valid profile still matches');

is($engine && scalar(grep { $_->answer eq 'broken' } $engine->all_filters), 0, 'the invalid profile is skipped');

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


