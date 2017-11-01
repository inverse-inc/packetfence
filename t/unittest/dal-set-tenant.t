#!/usr/bin/perl

=head1 NAME

dal-set-tenant

=cut

=head1 DESCRIPTION

unit test for dal-set-tenant

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

use Test::More tests => 3;
use pf::dal;
use pf::dal::tenant;

#This test will running last
use Test::NoWarnings;

my $old_tentant_id = pf::dal->get_tenant;

my ($status, $iter) = pf::dal::tenant->search(
    -columns => ["MAX(id)|max_id"],
    -group_by => 'id',
    -with_class => undef,
);

my $data = $iter->next;

my $fake_tenant_id = $data->{max_id} + $$ + int(rand($$));

pf::dal->set_tenant(undef);

is($old_tentant_id, pf::dal->get_tenant, "Do not change tenant if it is undef");

pf::dal->set_tenant($fake_tenant_id);

isnt($fake_tenant_id, pf::dal->get_tenant, "Do not allow a non existent tenant_id to be set");

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

