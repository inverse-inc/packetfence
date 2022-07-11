package pf::dal::ctx;

=head1 NAME

pf::dal::ctx -

=head1 DESCRIPTION

pf::dal::ctx

=cut

use strict;
use warnings;
use pf::error qw(is_error);
our $GLOBAL = __PACKAGE__->new;

my @DAL_OBJS;

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    return bless({}, $class);
}

sub begin {
    my ($self) = @_;
    $self->_clear;
    return;
}

sub _clear {
    my ($self) = @_;
    @{$self->{DAL_OBJS}} = ();
}

sub add {
    my ($self, @dals) = @_;
    push @{$self->{DAL_OBJS}}, @dals;
}

sub flush {
    my ($self) = @_;
    for my $dal (@{$self->{DAL_OBJS}}) {
        my $status = $dal->save;
        if (is_error($status)) {

        }
    }

    $self->_clear;
}

sub find {
    my ($self, $dal, $lookup) = @_;
    my ($status, $obj) = $dal->find_or_new($lookup);
    if (is_error($status)) {
        return undef;
    }

    $self->add($obj);
    return $obj;
}

sub add_global {
    $GLOBAL->add(@_);
}

sub find_global {
    $GLOBAL->find(@_);
}

sub flush_global {
    $GLOBAL->flush;
}

sub begin_global {
    $GLOBAL->begin;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
