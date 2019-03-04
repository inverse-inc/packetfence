#!/usr/bin/perl

=head1 NAME

tenant

=cut

=head1 DESCRIPTION

unit test for tenant

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::cmd::pf::tenant;
use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::dal::tenant;
use pf::error qw(is_success);

my $tenant_name = "test_$$";

my $cmd = "perl -T -I/usr/local/pf/t -Msetup_test_config /usr/local/pf/bin/pfcmd.pl tenant add $tenant_name";
system($cmd);

is($?, 0, "Adding tenant $tenant_name via pfcmd succeeded");

my ($status, $iter) = pf::dal::tenant->search(
    -where => {
        name => $tenant_name,
    },
    -with_class => undef,
);

ok(is_success($status), "Query was for tenant was succcessful");

my $tenant = $iter->next;

is($tenant_name, $tenant->{name},  "$tenant_name was really added to the database");

{
    local $? = $?;
    system($cmd);
    ok($? != 0, "Adding tenant $tenant_name twice via pfcmd failed");
}

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

1;

