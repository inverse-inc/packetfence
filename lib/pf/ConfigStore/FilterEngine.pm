package pf::ConfigStore::FilterEngine;

=head1 NAME

pf::ConfigStore::VlanFilters add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::VlanFilters

=cut

use strict;
use warnings;
use Moo;
use namespace::autoclean;
extends 'pf::ConfigStore';
use pf::condition_parser qw(parse_condition_string ast_to_object);

sub ordered_arrays { }

=head2 cleanupBeforeCommit

cleanupBeforeCommit

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    for my $i ($self->ordered_arrays) {
        $self->flatten_to_ordered_array($item, @$i);
    }

    my $top_op = $item->{condition}{op};
    $item->{top_op} = undef;
    if ($top_op eq 'and' || $top_op eq 'or' || $top_op eq 'not_and' || $top_op eq 'not_or') {
        if (@{$item->{condition}{values}} == 1) {
            $item->{top_op} = $top_op;
        }
    }
    $item->{condition} = pf::condition_parser::object_to_str($item->{condition});
    $self->flatten_list($item, $self->_fields_expanded);
    return ;
}

sub cleanupAfterRead {
    my ($self, $id, $item, $idKey) = @_;
    $self->expand_ordered_array($item, 'actions', 'action');
    $self->expand_list($item, $self->_fields_expanded);
    $self->expandCondition($id, $item, $idKey);
    return;
}

sub expandCondition {
    my ($self, $id, $item, $idKey) = @_;
    my ($ast, $err) = parse_condition_string($item->{condition});
    my $condition = ast_to_object($ast);
    my $top_op = delete $item->{top_op};
    if ($top_op) {
        if ($top_op eq 'and' || $top_op eq 'or') {
            $condition = { op => $top_op, values => [$condition]};
        } elsif ($top_op eq 'not_and' || $top_op eq 'not_or') {
            my $op = $condition->{op};
            if ($op eq 'not') {
                $condition->{op} = $top_op;
            }
        }
    }

    $item->{condition} = $condition;
    return;
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(scopes);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

