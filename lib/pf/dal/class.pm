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
use Class::XSAccessor {
    getters => [qw(action)],
};

sub find_from_tables {
    [-join => qw(class =>{class.security_event_id=action.security_event_id} action)],
}

our @COLUMN_NAMES = (
    (map {"class.$_|$_"} @pf::dal::_class::FIELD_NAMES),
    'group_concat(action.action order by action.action asc)|action'
);


=head2 find_select_args

find_select_args

=cut

sub find_select_args {
    my ($self, @args) = @_;
    my $select_args = $self->SUPER::find_select_args(@args);
    $select_args->{'-group_by'} = 'class.security_event_id';
    return $select_args;
}

=head2 find_columns

Override the standard field names for node

=cut

sub find_columns {
    [@COLUMN_NAMES]
}

=head2 to_hash_fields

to_hash_fields

=cut

sub to_hash_fields {
    return [@pf::dal::_class::FIELD_NAMES, qw(action)];
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
