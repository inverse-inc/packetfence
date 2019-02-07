package pfappserver::Base::Controller::Crud::Clone;
=head1 NAME

pfappserver::Base::Controller::Crud::Clone

=head1 DESCRIPTION

Clone role for Crud controller

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;

=head1 METHODS

=head2 clone

clone action for crud style controllers

=cut

sub clone :Chained('object') :PathPart('clone') :Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $idKey = $model->idKey;
    my $item = $c->stash->{$itemKey};
    $c->stash->{cloned_id} = $item->{$idKey};
    if ($c->request->method eq 'POST') {
        $self->_processCreatePost($c);
    }
    else {
        delete $item->{$idKey};
        my $form = $self->getForm($c);
        $form->process(init_object => $item);
        $c->stash(form => $form);
    }
}

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

