package pf::UnifiedApi::Controller::Violations;

=head1 NAME

pf::UnifiedApi::Controller::Violations -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Violations

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::violation;

has dal => 'pf::dal::violation';
has id_key => 'violation_id';
has resource_id => 'id';


sub open_uniq {
    my ($self) = @_;
    my @violations = pf::violation::violation_view_open_uniq();
    return $self->render(json => { items => \@violations } ) if scalar @violations > 0 and defined($violations[0]);
    return $self->render(json => undef);
}

sub list_by_search {
    my ($self) = @_;
    my $search = $self->param('search');
    return $self->_list_by_mac($search) if pf::util::valid_mac($search);
    return $self->_list_by_id($search);
}

sub _list_by_mac {
    my ($self, $mac) = @_;
    my @violations = pf::violation::violation_view_desc($mac);
    return $self->render(json => { items => \@violations }) if scalar @violations > 0 and defined($violations[0]);
    return $self->render(json => undef);
}

sub _list_by_id {
    my ($self, $id) = @_;
    my @violation = pf::violation::violation_view($id);
    return $self->render(json => $violation[0] ) if scalar @violation > 0 and defined($violation[0]);
    return $self->render(json => undef);
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
