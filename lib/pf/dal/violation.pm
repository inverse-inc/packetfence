package pf::dal::violation;

=head1 NAME

pf::dal::violation - pf::dal module to override for the table violation

=cut

=head1 DESCRIPTION

pf::dal::violation

pf::dal implementation for the table violation

=cut

use strict;
use warnings;

use base qw(pf::dal::_violation);
use Class::XSAccessor {
    getters => [qw(description)]
};

our @COLUMN_NAMES = (
    @pf::dal::_violation::COLUMN_NAMES,
    qw(class.description|description)
);

=head2 find_from_tables

Join the node_category table information in the node results

=cut

sub find_from_tables {
     [-join => qw(violation <=>{violation.vid=class.vid} class)]
}

=head2 find_columns

Override the standard field names for violation

=cut

sub find_columns {
    [@COLUMN_NAMES]
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
