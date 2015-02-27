package pfappserver::PacketFence::Controller::Config::Authentication;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Authentication - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use Log::Log4perl qw(get_logger);
use pf::authentication;
use pfappserver::Form::Config::Authentication;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 SUBROUTINES

=head2 index

Show list of authentication sources. Allow user to order the list.

/config/authentication/index

=cut

sub index :Path :Args(0) :AdminRole('USERS_SOURCES_READ') {
    my ($self, $c) = @_;

    my ($sources);

    (undef, $sources) = $c->model('Config::Authentication')->readAll();
    my $internal_types = availableAuthenticationSourceTypes('internal');
    my $external_types = availableAuthenticationSourceTypes('external');
    my $exclusive_types = availableAuthenticationSourceTypes('exclusive');
    my $form = pfappserver::Form::Config::Authentication->new(ctx => $c,
                                                   init_object => {sources => $sources});
    $form->process();

    $c->stash(
        internal_types  => $internal_types,
        external_types  => $external_types,
        exclusive_types => $exclusive_types,
        form => $form,
        template => 'config/authentication.tt'
    );
}

=head2 update

Update the authentication sources order.

/config/authentication/update

=cut

sub update :Path('update') :Args(0) :AdminRole('USERS_SOURCES_UPDATE') {
    my ($self, $c) = @_;

    my ($form, $status, $message);
    $c->stash->{current_view} = 'JSON';

    $form = $c->form("Config::Authentication");
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        my $model = $c->model('Config::Authentication');
        ($status, $message) = $model->sortItems($form->value->{sources});
        if(is_success($status)) {
            $self->_commitChanges($c,$model);
        }
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message

}



=head2 _commitChanges

Commit changes would want to refactor to model
#Would need to refactor to the model

=cut

sub _commitChanges {
    my ($self,$c,$model) = @_;
    my $logger = get_logger();
    my ($status,$message);
    eval {
        ($status,$message) = $model->commit();
    };
    if($@) {
        $status = HTTP_INTERNAL_SERVER_ERROR;
        $message = $@;
    }
    if(is_error($status)) {
        $c->stash(
            current_view => 'JSON',
            status_msg => $message,
        );
        $model->rollback();
    }
    $logger->info($message);
    $c->response->status($status);
}

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

__PACKAGE__->meta->make_immutable;

1;
