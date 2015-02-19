package pfappserver::Role::Controller::BulkActions;

=head1 NAME

pfappserver::Role::Controller::BulkActions add documentation

=cut

=head1 DESCRIPTION

pfappserver::Role::Controller::BulkActions

=cut

use strict;
use warnings;
use MooseX::MethodAttributes::Role;
use HTTP::Status qw(:constants is_error is_success);

=head2 bulk_close

=cut

sub bulk_close : Local {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkCloseViolations(@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 bulk_register

=cut

sub bulk_register : Local {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkRegister(@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 bulk_deregister

=cut

sub bulk_deregister : Local {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkDeregister(@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 bulk_apply_role

=cut

sub bulk_apply_role : Local : Args(1) {
    my ( $self, $c, $role ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkApplyRole($role,@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 bulk_apply_violation

=cut

sub bulk_apply_violation : Local : Args(1) {
    my ( $self, $c, $violation ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkApplyViolation($violation,@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

=head2 bulk_reevaluate_access

=cut

sub bulk_reevaluate_access : Local {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkReevaluateAccess(@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

