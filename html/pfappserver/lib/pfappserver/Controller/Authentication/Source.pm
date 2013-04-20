package pfappserver::Controller::Authentication::Source;

=head1 NAME

pfappserver::Controller::Authentication::Source - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pf::authentication;
use pfappserver::Form::Authentication::Source;
use pfappserver::Form::Authentication::Rule;

BEGIN { extends 'pfappserver::Base::Controller::Base'; }

=head1 SUBROUTINES

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('Controller::Authentication', 'index');
}

=head2 create

Create a rule of the specified type

/authentication/create/*

=cut

sub create :Local :Args(1) {
    my ($self, $c, $type) = @_;

    $c->stash->{action_uri} = $c->req->uri;
    $c->stash->{source} = {};
    $c->stash->{source}->{type} = $type; # case-sensitive

    if ($c->request->method eq 'POST') {
        # Create the source from the update action
        $c->stash->{source}->{id} = $c->req->params->{id};
        $c->forward('update');
        if(is_success($c->response->status)) {
            $c->response->location( $c->pf_hash_for($self->action_for('read'), [$c->stash->{source}->{id}]));
        }
    }
    else {
        # Show an empty form
        $c->forward('read');
    }
}

=head2 object

Authentication source chained dispatcher

/authentication/*

=cut

sub object :Chained('/') :PathPart('authentication') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $source = getAuthenticationSource($id);

    if (defined $source) {
        $c->stash->{source_id} = $id;
        $c->stash->{source} = $source;
    }
    else {
        $c->response->status(HTTP_NOT_FOUND);
        $c->stash->{status_msg} = $c->loc('The authentication source was not found.');
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 read

/authentication/*/read

=cut

sub read :Chained('object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;

    my ($form_type, $form);

    if ($c->stash->{source}->{id} && !$c->stash->{action_uri}) {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->{stash}->{source}->{id}]);
    }

    # Load the appropriate source module
    $form_type = "Authentication::Source::" . $c->stash->{source}->{type};
    $form = $c->form($form_type);
    unless ($form) {
        $c->log->error("cannot load form $form_type");
        $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
        $c->stash->{status_msg} = $c->loc('Unexpected error. See server-side logs for details.');
        $c->stash->{current_view} = 'JSON';
    }
    else {
        my %obj = ();
        if ($c->stash->{source_id}) {
            my @attrs = map { $_->name } $c->stash->{source}->meta->get_all_attributes();
            @obj{@attrs} = @{$c->stash->{source}}{@attrs};
        }
        $form = $form->new(ctx => $c, init_object => \%obj);
        $form->process();
        $c->stash->{form} = $form;
        $c->stash->{template} = 'authentication/source/read.tt' unless ($c->stash->{template});
    }
}

=head2 update

/authentication/*/update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self, $c) = @_;

    my ($form_type, $form, $status, $message);

    # Load the appropriate source module
    $form_type = 'pfappserver::Form::Authentication::Source::' . $c->stash->{source}->{type};
    eval "require $form_type";
    if ($@) {
        $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
        $c->stash->{status_msg} = $c->loc('Unexpected error. See server-side logs for details.');
        $c->detach();
        return;
    }
    $form = $form_type->new(ctx => $c, id => $c->stash->{source_id});
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) = $c->model('Authentication::Source')->update($c->stash->{source_id},
                                                                          $c->stash->{source},
                                                                          $form->value);
    }

    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$form->value->{id}]);
        $c->stash->{form} = $form;
        $c->stash->{template} = 'authentication/source/read.tt';
        $c->stash->{message} = $message;
    }
}

=head2 delete

/authentication/*/delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;

    my ($status, $message) = $c->model('Authentication::Source')->delete($c->stash->{source});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message;
    }

    $c->stash->{current_view} = 'JSON';
}

=head2 test

Test the connection to a source of a specific type.

=cut

sub test :Local :Args(1) {
    my ($self, $c, $type) = @_;

    my ($status, $message) = (HTTP_METHOD_NOT_ALLOWED, 'The source cannot be tested.');
    my %attrs = ();
    foreach my $param (keys %{$c->request->params}) {
        $attrs{$param} = $c->request->param($param) if ($c->request->param($param));
    }
    eval {
        my $source = newAuthenticationSource($type, 'test', \%attrs);
        if ($source && $source->can('test')) {
            ($status, $message) = $source->test();
            $status = $status ? HTTP_OK : HTTP_BAD_REQUEST;
        }
    };
    if ($@) {
        $c->log->debug($@);
        $status = HTTP_INTERNAL_SERVER_ERROR;
        $message = $c->loc("Unexpected error. See server-side logs for details.");
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $c->loc($message);
    $c->stash->{current_view} = 'JSON';
}

=head2 rule_create

/authentication/*/rule/create

=cut

sub rule_create :Chained('object') :PathPart('rule/create') :Args(0) {
    my ($self, $c) = @_;

    $c->stash->{action_uri} = $c->req->uri;
    if ($c->request->method eq 'POST') {
        $c->forward('rule_update');
    }
    else {
        $c->forward('rule_read');
    }
}

=head2 rules_read

/authentication/*/rules

=cut

sub rules_read :Chained('object') :PathPart('rules/read') :Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'authentication/source/rules_read.tt';
    $c->forward('read');
}

=head2 rule_object

Rule chained dispatcher

/authentication/*/rule/*

=cut

sub rule_object :Chained('object') :PathPart('rule') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $rule = $c->stash->{source}->getRule($id);

    if (defined $rule) {
        $c->stash->{rule} = $rule;
    }
    else {
        $c->response->status(HTTP_NOT_FOUND);
        $c->stash->{status_msg} = $c->loc('The rule was not found.');
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 rule_read

/authentication/*/rule/*/read

=cut

sub rule_read :Chained('rule_object') :PathPart('read') :Args(0) {
    my ($self, $c) = @_;

    my ($form);

    if ($c->stash->{rule} && !$c->stash->{action_uri}) {
        $c->stash->{action_uri} = $c->uri_for($self->action_for('rule_update'),
                                              [$c->{stash}->{source}->{id}, $c->{stash}->{rule}->{id}]);
    }

    $form = pfappserver::Form::Authentication::Rule->new(ctx => $c,
                                                         init_object => $c->stash->{rule},
                                                         source_type => $c->stash->{source}->{type},
                                                         attrs => $c->stash->{source}->available_attributes());
    $form->process;
    unless ($c->stash->{rule}) {
        # New rule; add a default action
        $form->field('actions')->add_extra;
    }

    $c->stash->{form} = $form;

    $c->stash->{template} = 'authentication/source/rule_read.tt';
}

=head2 rule_update

/authentication/*/rule/*/update

=cut

sub rule_update :Chained('rule_object') :PathPart('update') :Args(0) {
    my ($self, $c) = @_;

    my ($form, $status, $message);

    $form = pfappserver::Form::Authentication::Rule->new(ctx => $c,
                                                         source_type => $c->stash->{source}->{type},
                                                         attrs => $c->stash->{source}->available_attributes());
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) =
          $c->model('Authentication::Source')->updateRule($c->stash->{source}->{id},
                                                          $c->stash->{rule}? $c->stash->{rule}->{id} : undef,
                                                          $form->value);
    }
    if (is_error($status)) {
        # Error -- return a JSON hash
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
        $c->stash->{current_view} = 'JSON';
    }
    else {
        # Success -- reload the source
        $c->stash->{action_uri} = undef;
        $c->forward('rules_read');
    }
}

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
