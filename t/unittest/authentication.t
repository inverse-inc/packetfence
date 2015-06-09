#!/usr/bin/perl
=head1 NAME

autentication

=cut

=head1 DESCRIPTION

autentication

=cut

use strict;
use warnings;

use Test::More tests => 12;                      # last test to print

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
            'type'  => 'set_role',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '1D',
            'type'  => 'set_access_duration',
            'class' => 'authentication',
        }),
        pf::Authentication::Action->new({
            'value' => '1',
            'type'  => 'mark_as_sponsor',
            'class' => 'administration',
        })
    ],
    "match all email actions"
);

my $source_id_ref;
is_deeply(
    pf::authentication::match("htpasswd1", { username => 'user_manager', rule_class => 'administration' }, undef, \$source_id_ref),
    [
        pf::Authentication::Action->new({
            'value' => 'User Manager',
            'type'  => 'set_access_level',
            'class' => 'administration',
        })
    ],
    "match htpasswd1 by username"
);

is($source_id_ref, "htpasswd1", "Source id ref is found");

is( pf::authentication::match(
        [getAuthenticationSource("htpasswd1"), getAuthenticationSource("email")],
        {username => 'user@domain.com', rule_class => 'administration'},
        'mark_as_sponsor'
    ),
    1,
    "Return action in second matching source"
);

is( pf::authentication::match(
        [getAuthenticationSource("htpasswd1"), getAuthenticationSource("email")],
        {username => 'user@domain.com', rule_class => 'administration'},
        'set_access_level'
    ),
    'Violation Manager',
    "Return action in first matching source"
);

is(
    pf::authentication::match("htpasswd1", { username => 'set_access_duration_test' }, 'set_access_duration'),undef,
    "No longer match on set_access_duration "
);

my $value = pf::authentication::match("htpasswd1", { username => 'set_access_duration_test' }, 'set_unreg_date');

ok( $value , "set_access_duration matched on set_unreg_date");

ok ( $value =~ /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d/, "Value returned by set_access_duration is a date");

is(pf::authentication::match("htpasswd1", { username => 'set_unreg_date_test' }, 'set_unreg_date'),'2022-02-02', "Set unreg date test");

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


