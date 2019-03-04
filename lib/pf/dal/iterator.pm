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

=head2 new

Create a new iterator

=cut

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my $self = {%$args};
    return bless $self, $class;
}

=head2 next

Get the next item from the iterator

=cut

sub next {
    my ($self) = @_;
    my $sth = $self->sth;
    return undef unless defined $sth;
    my $row = $sth->fetchrow_hashref;
    unless (defined $row) {
        $self->finish;
        return undef;
    }
    my $class = @_ > 1 ? $_[1] : $self->class;
    return defined $class ? $class->new_from_row($row) : $row;
}

=head2 all

Get all the items for the iterator

=cut

sub all {
    my ($self) = @_;
    my $sth = $self->sth;
    return undef unless defined $sth;
    my $items = $sth->fetchall_arrayref({});
    $self->finish;
    my $class = @_ > 1 ? $_[1] : $self->class;
    return $items unless defined $class;
    return [map {$class->new_from_row($_)} @$items];
}

=head2 rows

rows

=cut

sub rows {
    my ($self) = @_;
    my $sth = $self->sth;
    return undef if !defined $sth;
    return $sth->rows;
}


=head2 finish

finish

=cut

sub finish {
    my ($self) = @_;
    my $sth = $self->sth;
    if (!defined $sth) {
        return;
    }
    $sth->finish;
    $self->sth(undef);
    return ;
}

=head2 DESTROY

Cleanup after iterator goes out of scope

=cut

sub DESTROY {
    my ($self) = @_;
    $self->finish;
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

