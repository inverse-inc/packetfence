package pf::dal::iterator;

=head1 NAME

pf::dal::iterator -

=cut

=head1 DESCRIPTION

pf::dal::iterator

=cut

use strict;
use warnings;
use Class::XSAccessor {
    accessors => [qw(sth class)],
};

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my $self = {%$args};
    return bless $self, $class;
}

sub next_item {
    my ($self) = @_;
    my $sth = $self->sth;
    my $row = $sth->fetchrow_hashref;
    return undef unless defined $row;
    my $class = $self->class;
    return $class->new_from_table($row);
}

sub DESTROY {
    my ($self) = @_;
    $self->sth->finish;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

