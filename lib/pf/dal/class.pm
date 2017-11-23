package pf::dal::class;

=head1 NAME

pf::dal::class - pf::dal module to override for the table class

=cut

=head1 DESCRIPTION

pf::dal::class

pf::dal implementation for the table class

=cut

use strict;
use warnings;

use base qw(pf::dal::_class);

=head2 remove_classes_not_defined

remove classes not defined

=cut

sub remove_classes_not_defined {
    my ($self, $ids) = @_;
    my $sqla = $self->get_sql_abstract;
    my ($sql, @bind) = $sqla->delete(
        -from => $self->table,
        -where => { vid => { -not_in => $ids } },
    );
    my ($status, $sth) = $self->db_execute($sql, @bind);
    $sth->finish;
    return $status;
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
