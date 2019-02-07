package pf::dal::password;

=head1 NAME

pf::dal::password - pf::dal module to override for the table password

=cut

=head1 DESCRIPTION

pf::dal::password

pf::dal implementation for the table password

=cut

use strict;
use warnings;

use base qw(pf::dal::_password);

my @PERSON_FIELDS = qw(firstname lastname email telephone company address notes);

our @COLUMN_NAMES = (
    (map {"password.$_|$_"} @pf::dal::_password::FIELD_NAMES),
    'node_category.name|category',
    (map {"person.$_|$_"} @PERSON_FIELDS)
);

use Class::XSAccessor {
    getters => \@PERSON_FIELDS,
};

=head2 find_columns

Override the standard field names

=cut

sub find_columns {
    [@COLUMN_NAMES]
}

=head2 find_from_tables

Join the node_category table information in the node results

=cut

sub find_from_tables {
    [-join => qw(password =>{password.category=node_category.category_id} node_category =>{password.pid=person.pid} person)],
}

=head2 to_hash_fields

to_hash_fields

=cut

sub to_hash_fields {
    return [@pf::dal::_password::FIELD_NAMES, @PERSON_FIELDS];
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
