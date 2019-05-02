package pf::dal::person;

=head1 NAME

pf::dal::person - pf::dal module to override for the table person

=cut

=head1 DESCRIPTION

pf::dal::person

pf::dal implementation for the table person

=cut

use strict;
use warnings;

use base qw(pf::dal::_person);

my @PASSWORD_FIELDS = qw(
    password
    valid_from
    expiration
    access_duration
    access_level
    unregdate
    login_remaining
);

our @COLUMN_NAMES = (
    (map {"person.$_|$_"} @pf::dal::_person::FIELD_NAMES),
    (map {"password.$_|$_"} @PASSWORD_FIELDS),
    'password.sponsor|can_sponsor',
    'password.category|category_id',
    'node_category.name|category',
);

use Class::XSAccessor {
# The getters for current location log entries
    getters   => [@PASSWORD_FIELDS, qw(can_sponsor)],
};

=head2 find_from_tables

Join the node_category table information in the node results

=cut

sub find_from_tables {
    [-join => 'person', '=>{person.pid=password.pid,person.tenant_id=password.tenant_id}', qw(password =>{node_category.category_id=password.category} node_category)],
}

=head2 find_columns

Override the standard field names for node

=cut

sub find_columns {
    [@COLUMN_NAMES]
}

sub to_hash_fields {
    return [@pf::dal::_person::FIELD_NAMES, @PASSWORD_FIELDS, qw(can_sponsor nodes category category_id)];
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
