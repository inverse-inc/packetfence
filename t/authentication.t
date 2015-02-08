#!/usr/bin/perl
=head1 NAME

autentication

=cut

=head1 DESCRIPTION

autentication

=cut

use strict;
use warnings;

use Test::More tests => 6;                      # last test to print

use Test::NoWarnings;
use diagnostics;
BEGIN {
    use lib '/usr/local/pf/lib';
    use PfFilePaths;
}


# pf core libs

use_ok("pf::authentication");

is(pf::authentication::match("bad_source_name",{ username => 'test' }), undef, "Return undef for an invalid name of source");

is_deeply(
    pf::authentication::match("email", { username => 'user_manager' }),
    [
        pf::Authentication::Action->new({
            'value' => 'guest',
            'type' => 'set_role'
        }),
        pf::Authentication::Action->new({
            'value' => '1D',
            'type' => 'set_access_duration'
        })
    ],
    "match all email actions"
);

my $source_id_ref;
is_deeply(
    pf::authentication::match("htpasswd1", { username => 'user_manager' }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'User Manager',
            'type' => 'set_access_level'
        })
    ],
    "match htpasswd1 by username"
);

is($source_id_ref, "htpasswd1", "Source id ref is found");

is(pf::authentication::username_from_email('user@domain.com'), 'htpasswd1', "Found username associated to an email");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


