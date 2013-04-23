package pfappserver::Controller::Authentication;

=head1 NAME

pfappserver::Controller::Authentication - Catalyst Controller

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

BEGIN {
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud::Config' => { -excludes => [ qw(getForm) ] };
}

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    pf::config::cached::ReloadConfigs();
    $c->stash->{current_model_instance} = $c->model("Config::Authentication")->new;
}

=head2 index

Show list of authentication sources. Allow user to order the list.

/authentication/index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    my ($sources, $types, $form);

    $sources = getAuthenticationSource(undef);
    $types = availableAuthenticationSourceTypes();
    $form = pfappserver::Form::Authentication->new(ctx => $c,
                                                   init_object => {sources => $sources});
    $form->process();

    # Remove sources that must be unique and that are already defined
    $c->stash->{types} = [];
    foreach my $type (@$types) {
        unless (grep { $_->{unique} && $_->{type} eq $type } @$sources) {
            push(@{$c->stash->{types}}, $type);
        }
    }

    $c->stash->{form} = $form;
    $c->stash->{template} = 'configuration/authentication.tt';
}

=head2 update

Update the authentication sources order.

/authentication/update

=cut

sub update :Path('update') :Args(0) {
    my ($self, $c) = @_;

    my ($form, $status, $message);

    $form = pfappserver::Form::Authentication->new(ctx => $c);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) = $c->model('Authentication')->update($form->value->{sources});
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message

    $c->stash->{current_view} = 'JSON';
}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
