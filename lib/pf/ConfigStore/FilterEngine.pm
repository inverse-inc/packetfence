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
use List::MoreUtils qw(any);
use namespace::autoclean;
extends 'pf::ConfigStore';

sub ordered_arrays { }

=head2 cleanupBeforeCommit

cleanupBeforeCommit

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    for my $i ($self->ordered_arrays) {
        $self->flatten_to_ordered_array($item, @$i);
    }

    $self->flattenCondition($item, 'condition');
    $self->flatten_list($item, $self->_fields_expanded);
    return ;
}

sub cleanupAfterRead {
    my ($self, $id, $item, $idKey) = @_;
    for my $i ($self->ordered_arrays) {
        $self->expand_ordered_array($item, @$i);
    }
    $self->expand_list($item, $self->_fields_expanded);
    $self->expandCondition($item, 'condition');
    return;
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(scopes);
}

sub _update_section {
    my ($self, $section, $assignments) = @_;
    my $cachedConfig = $self->cachedConfig;
    my @array_items = $self->ordered_arrays;
    for my $p ($cachedConfig->Parameters($section)) {
        if ( any { $p =~ /^\Q$_->[1]\E\./ } @array_items ) {
            $cachedConfig->delval($section, $p);
        }
    }

    $self->SUPER::_update_section($section, $assignments);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

