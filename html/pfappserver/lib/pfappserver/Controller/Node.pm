package pfappserver::Controller::Node;

=head1 NAME

pfappserver::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

BEGIN { extends 'pfappserver::Base::Controller'; }

__PACKAGE__->config(
    action_args => {
        advanced_search => { model=> 'Search::Node', form => 'AdvancedSearch' },
    }
);

=head1 SUBROUTINES


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->go('simple_search');
}

=head2 simple_search

=cut

sub simple_search :SimpleSearch('Node') :Local :Args() { }

=head2 after _list_items

The method _list_items comes from pfappserver::Base::Controller and is called from Base::Action::SimpleSearch.

=cut

after _list_items => sub {
    my ($self, $c) = @_;

    my ($status,$roles) = $c->model('Roles')->list();
    $c->stash(roles => $roles);
};


=head2 advanced_search

=cut

sub advanced_search :Local :Args() {
    my ($self, $c, @args) = @_;
    my ($status, $status_msg, $result);
    my %search_results;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
        $c->stash(
            current_view => 'JSON',
        );
    }
    else {
        my $query = $form->value;
        ($status, $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(form => $form);
            $c->stash($result);
        }
    }
    (undef, $result) = $c->model('Roles')->list();
    $c->stash(
        status_msg => $status_msg,
        roles => $result
    );
    $c->response->status($status);
}


=head2 object

Node controller dispatcher

=cut

sub object :Chained('/') :PathPart('node') :CaptureArgs(1) {
    my ( $self, $c, $mac ) = @_;

    my ($status, $node_ref, $roles_ref);

    ($status, $node_ref) = $c->model('Node')->exists($mac);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $node_ref;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    ($status, $roles_ref) = $c->model('Roles')->list();
    if (is_success($status)) {
        $c->stash->{roles} = $roles_ref;
    }

    $c->stash->{mac} = $mac;
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;

    my ($nodeStatus, $result);
    my ($form, $status, $roles);

    # Form initialization :
    # Retrieve node details and status

    ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }
    ($status, $result) = $c->model('Config::Switch')->readAll();
    if (is_success($status)) {
        my %switches = map { $_->{id} => { type => $_->{type},
                                           mode => $_->{mode} } } @$result;
        $c->stash->{switches} = \%switches;
    }
    $nodeStatus = $c->model('Node')->availableStatus();
    $form = $c->form("Node" ,
        init_object => $c->stash->{node},
        status => $nodeStatus,
        roles => $c->stash->{roles}
    );
    $form->process();
    $c->stash->{form} = $form;

#    my @now = localtime;
#    $c->stash->{now} = { date => POSIX::strftime("%Y-%m-%d", @now),
#                         time => POSIX::strftime("%H:%M", @now) };
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message);
    my ($form, $nodeStatus);

    $nodeStatus = $c->model('Node')->availableStatus();
    $form = $c->form("Node" ,
        status => $nodeStatus,
        roles => $c->stash->{roles}
    );
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) = $c->model('Node')->update($c->stash->{mac}, $form->value);
    }
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = $c->model('Node')->delete($c->stash->{mac});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 violations

=cut

sub violations :Chained('object') :PathPart :Args(0) {
    my ($self, $c) = @_;
    my ($status, $result) = $c->model('Node')->violations($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{items} = $result;
        $c->stash->{template} = 'node/violations.tt';
        (undef, $result) = $c->model('Config::Violations')->readAll();
        my @violations = grep { $_->{id} ne 'defaults' } @$result; # remove defaults
        $c->stash->{violations} = \@violations;
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 triggerViolation

=cut

sub triggerViolation :Chained('object') :PathPart('trigger') :Args(1) {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Config::Violations')->hasId($id);
    if (is_success($status)) {
        ($status, $result) = $c->model('Node')->addViolation($c->stash->{mac}, $id);
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    if (is_success($status)) {
        $c->forward('violations');
    }
    else {
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 closeViolation

=cut

sub closeViolation :Path('close') :Args(1) {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Node')->closeViolation($id);
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    $c->stash->{current_view} = 'JSON';
}

=head2 bulk_close

=cut

sub bulk_close: Local {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status, $status_msg);
    my $request = $c->request;
    if($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $c->model('Node')->bulkCloseViolations(@ids);
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
    );
}

=head2 bulk_register

=cut

sub bulk_register: Local {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status, $status_msg);
    my $request = $c->request;
    if($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $c->model('Node')->bulkRegister(@ids);
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
    );
}

=head2 bulk_deregister

=cut

sub bulk_deregister: Local {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status, $status_msg);
    my $request = $c->request;
    if($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $c->model('Node')->bulkDeregister(@ids);
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
    );
}

=head2 bulk_apply_role

=cut

sub bulk_apply_role: Local : Args(1) {
    my ($self, $c, $role) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status, $status_msg);
    my $request = $c->request;
    if($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $c->model('Node')->bulkApplyRole($role,@ids);
    } else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
