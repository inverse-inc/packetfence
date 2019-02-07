package pfappserver::Base::Controller::Crud::Config::Clone;
=head1 NAME

pfappserver::Base::Controller::Crud::Config::Clone

=head1 DESCRIPTION

Clone role for Crud controller

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;
with 'pfappserver::Base::Controller::Crud::Clone';

=head1 METHODS

=head2 clone

clone action for crud style controllers

=cut

after clone => sub {
    my ($self,$c) = @_;
    if(is_success($c->response->status) && $c->request->method eq 'POST' ) {
        $self->_commitChanges($c);
    }
};

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

