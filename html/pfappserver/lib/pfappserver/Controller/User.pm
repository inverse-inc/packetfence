package pfappserver::Controller::User;

=head1 NAME

pfappserver::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pfappserver::Form::User::Create;
use pfappserver::Form::User::Create::Single;
use pfappserver::Form::User::Create::Multiple;
use pfappserver::Form::User::Create::Import;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=head2 auto

Allow only authenticated users

=cut

sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->req->referer);
        $c->stash->{template} = 'admin/unauthorized.tt';
        $c->detach();
        return 0;
    }

    return 1;
}

=head2 create

/user/create

=cut

sub create :Local {
    my ($self, $c) = @_;

    my (@roles, $form, $form_single, $form_multiple, $form_import);
    my ($type, %data, @options);
    my ($status, $result, $message);

    ($status, $result) = $c->model('Roles')->list();
    if (is_success($status)) {
        @roles = map { $_->{name} => $_->{name} } @$result;
    }

    $form = pfappserver::Form::User::Create->new(ctx => $c, roles => \@roles);
    $form_single = pfappserver::Form::User::Create::Single->new(ctx => $c);
    $form_multiple = pfappserver::Form::User::Create::Multiple->new(ctx => $c);
    $form_import = pfappserver::Form::User::Create::Import->new(ctx => $c);

    $form->process(params => $c->request->params);
    $form_single->process(params => $c->request->params);
    $form_multiple->process(params => $c->request->params);
    
    if ($c->request->method eq 'POST') {     
        # Create new user accounts
        $type = $c->request->param('type');
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $message = $form->field_errors;
        }
        elsif ($type eq 'single') {
            if ($form_single->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_single->field_errors;
            }
            else {
                %data = (%{$form->value}, %{$form_single->value});
                ($status, $message) = $c->model('User')->createSingle(\%data, $c->user);
                @options = ('mail');
            }
        }
        elsif ($type eq 'multiple') {
            if ($form_multiple->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_multiple->field_errors;            
            }
            else {
                %data = (%{$form->value}, %{$form_multiple->value});
                ($status, $message) = $c->model('User')->createMultiple(\%data, $c->user);
            }
        }
        elsif ($type eq 'import') {
            my $params = $c->request->params;
            $params->{users_file} = $c->req->upload('users_file');
            $form_import->process(params => $params);
            if ($form_import->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_import->field_errors;            
            }
            else {
                %data = (%{$form->value}, %{$form_import->value});
                ($status, $message) = $c->model('User')->importCSV(\%data, $c->user);
                @options = ('mail');
            }
        }
        else {
            $status = $STATUS::INTERNAL_SERVER_ERROR;
        }

        $c->response->status($status);
        $c->stash->{status} = $status;

        if (is_success($status)) {
            # List the created accounts
            my @pids = map { $_->{pid} } @{$message};
            $c->stash->{users} = $message;
            $c->stash->{pids} = \@pids;
            $c->stash->{options} = \@options;
            $c->stash->{template} = 'user/list_password.tt';
        }
        else {
            $c->stash->{status_msg} = $message; # TODO: localize error message
            $c->stash->{current_view} = 'JSON';
        }
    }
    else {
        # Initial display of the page
        $form_import->process();
        $form->field('actions')->add_extra; # an action must be chosen
        
        $c->stash->{form} = $form;
        $c->stash->{form_single} = $form_single;
        $c->stash->{form_multiple} = $form_multiple;
        $c->stash->{form_import} = $form_import;
        $c->stash->{template} = 'configuration/users.tt';
    }
}

=head2 print

Display a printable view of users credentials.

/user/print

=cut

sub print :Local {
    my ($self, $c) = @_;

    my ($status, $result);
    my @pids = split(/,/, $c->request->params->{pids});

    ($status, $result) = $c->model('User')->read($c, \@pids);
    if (is_success($status)) {
        $c->stash->{users} = $result;
    }

    $c->stash->{aup} = pf::web::guest::aup();
    $c->stash->{current_view} = 'Admin';
}

=head2 mail

Send users credentials by email.

/user/mail

=cut

sub mail :Local {
    my ($self, $c) = @_;

    my ($status, $result);
    my @pids = split(/,/, $c->request->params->{pids});

    ($status, $result) = $c->model('User')->mail($c, \@pids);
    if (is_success($status)) {
        $c->stash->{status_msg} = $c->loc('An email was sent to [_1] out of [_2] users.',
                                          scalar @pids, scalar @$result);
    }
    else {
        $c->stash->{status_msg} = $result;
    }

    $c->response->status($status);
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
