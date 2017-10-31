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

use Test::More tests => 6;
use pf::tenant qw(
    tenant_add
    tenant_view_by_name
);
use pf::person qw(person_view);
use pf::error qw(is_error is_success);

#This test will running last
use Test::NoWarnings;
my $tenant_name = "test_tenant_$$";
my $results = tenant_add({
    name => $tenant_name
});

ok($results, "tenant $tenant_name");

my $tenant = tenant_view_by_name($tenant_name);

ok(defined $tenant, "Get tenant by $tenant_name");

is($tenant->{name}, $tenant_name, "Get tenant by $tenant_name");

pf::dal->set_tenant($tenant->{id});

my $person = person_view("default");

ok($person, "Get default person for $tenant_name");

is($tenant->{id}, $person->{tenant_id}, "The default person has the tenant_id $tenant->{id}");

END {
    if ($tenant->{id}) {
        pf::dal::person->remove_items(
            -where => {
                tenant_id => $tenant->{id},
            }
        );
        pf::dal::tenant->remove_items(
            -where => {
                name => $tenant_name,
            }
        );
    }
}

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

