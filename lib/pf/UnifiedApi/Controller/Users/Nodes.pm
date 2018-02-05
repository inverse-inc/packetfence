package pf::UnifiedApi::Controller::Users::Nodes;

=head1 NAME

pf::UnifiedApi::Controller::Users::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Users::Nodes

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::person;

has 'dal' => 'pf::dal::node';

sub list {
    my ($self) = @_;
    my $user_id = $self->stash->{user_id};
    $self->render(json => { items => [person_nodes($user_id)]});
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
