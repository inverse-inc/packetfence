package pfappserver::Base::Controller::Crud::Copy;
=head1 NAME

pfappserver::Base::Controller::Crud::Copy

=head1 DESCRIPTION

Copy role for Crud controller

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;

=head1 METHODS

=head2 copy

copy action for crud style controllers

=cut

sub copy :Chained('object') :PathPart('copy') :Args(1) {
    my ( $self, $c, $to ) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my $from = $c->stash->{$idKey};
    my ($status,$status_msg) = $model->hasId($to);
    if(is_success($status)) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "$to already exists";
    } else {
        ($status,$status_msg) = $model->copy($from,$to);
    }
    $c->stash(
        status_msg   => $status_msg,
        current_view => 'JSON',
    );
    $c->response->status($status);
}

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

