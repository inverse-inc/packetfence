#!/usr/bin/perl

=head1 NAME

person_cleanup

=head1 DESCRIPTION

The person cleanup deletes the local accounts that can no longer log in: a zero
or missing password expiration is expired, as pf::password::validate_password
refuses it, while an expiration in the future keeps the account.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 10;
use DateTime;
use pf::person;
use pf::constants qw($ZERO_DATE);

#This test will running last
use Test::NoWarnings;

my $now = DateTime->now(time_zone => 'local');
my $future = $now->clone->add(days => 1)->strftime('%Y-%m-%d %H:%M:%S');
my $past = $now->clone->subtract(days => 1)->strftime('%Y-%m-%d %H:%M:%S');

ok(!pf::person::_local_account_still_valid($ZERO_DATE, $now), 'a zero expiration is expired');
ok(!pf::person::_local_account_still_valid(undef, $now), 'a missing expiration is expired');
ok(!pf::person::_local_account_still_valid($past, $now), 'a past expiration is expired');
ok(pf::person::_local_account_still_valid($future, $now), 'a future expiration is still valid');

my %passwords = (
    zero_expiry   => { expiration => $ZERO_DATE },
    past_expiry   => { expiration => $past },
    future_expiry => { expiration => $future },
);
my (@passwords_deleted, @persons_deleted);
{
    no warnings qw(redefine once);
    local *pf::password::view = sub { $passwords{$_[0]} };
    local *pf::password::_delete = sub { push @passwords_deleted, $_[0] };
    local *pf::person::person_delete = sub { push @persons_deleted, $_[0] };
    local *pf::person::persons_without_nodes = sub { map { { pid => $_ } } sort(keys %passwords), 'no_password' };

    pf::person::person_cleanup();
    is_deeply([sort @persons_deleted], [qw(no_password past_expiry zero_expiry)], 'person_cleanup deletes the expired accounts, a zero expiration included');
    is_deeply([sort @passwords_deleted], [qw(past_expiry zero_expiry)], 'and their passwords');

    @passwords_deleted = ();
    pf::person::single_person_cleanup('zero_expiry');
    is_deeply(\@passwords_deleted, ['zero_expiry'], 'single_person_cleanup deletes the password of a zero expiration');
    @passwords_deleted = ();
    ok(!pf::person::single_person_cleanup('future_expiry'), 'single_person_cleanup keeps a valid account');
    is_deeply(\@passwords_deleted, [], 'and its password');
}

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
