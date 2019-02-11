package pfappserver::PacketFence::Controller::User;

=head1 NAME

pfappserver::PacketFence::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use SQL::Abstract::More;
use JSON::MaybeXS;
use pf::admin_roles;
use pf::authentication qw(getAuthenticationSource);
use pf::config qw(%Config);
use pf::sms_carrier qw(sms_carrier_view_all);

BEGIN { extends 'pfappserver::Base::Controller'; }
with 'pfappserver::Role::Controller::BulkActions';

__PACKAGE__->config(
    action => {
        bulk_close           => { AdminRole => 'USERS_UPDATE' },
        bulk_register        => { AdminRole => 'USERS_UPDATE' },
        bulk_deregister      => { AdminRole => 'USERS_UPDATE' },
        bulk_apply_role      => { AdminRole => 'USERS_UPDATE' },
        bulk_apply_violation => { AdminRole => 'USERS_UPDATE' },
        bulk_delete          => { AdminRole => 'USERS_DELETE' },
    },
    action_args => {
        '*' => { model => 'User'},
        advanced_search => { model => 'Search::User', form => 'UserSearch' },
        simple_search => { model => 'Search::User', form => 'UserSearch' },
    },
);

=head1 SUBROUTINES

=head2 index

=cut

sub index :Path :Args(0) :AdminRoleAny(USERS_READ) :AdminRoleAny(USERS_READ_SPONSORED) {
    my ( $self, $c ) = @_;

    $c->go('simple_search');
}

=head2 simple_search

=cut

sub simple_search :Local :Args() :AdminRoleAny(USERS_READ): AdminRoleAny(USERS_READ_SPONSORED) {
    my ( $self, $c ) = @_;
    $c->forward('advanced_search');
}


=head2 object

User controller dispatcher

=cut

sub object :Chained('/') :PathPart('user') :CaptureArgs(1) {
    my ( $self, $c, $pid ) = @_;

    my ($status, $result);

    ($status, $result) = $self->getModel($c)->read($c, [$pid]);
    if (is_success($status)) {
        $c->stash->{user} = pop @{$result};
        # Fetch associated nodes
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) :AdminRoleAny(USERS_READ) :AdminRoleAny(USERS_READ_SPONSORED) {
    my ($self, $c) = @_;
    my ($form);
    my $user = $c->stash->{user};

    $form = $self->getForm($c, 'User', init_object => $user);
    $form->process();
    $form->field('actions')->add_extra unless @{$user->{actions}}; # an action must be chosen
    $c->stash->{form} = $form;
    my $password = $user->{password};
    if(defined $password) {
        $c->stash->{password_hash_type} = pf::password::password_get_hash_type($password);
    }
    $self->_add_sms_source($c, $user);
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) :AdminRole('USERS_DELETE') {
    my ($self, $c) = @_;

    my ($status, $result) = $self->getModel($c)->delete($c->stash->{user}->{pid});
    $self->audit_current_action($c, status => $status, pid => $c->stash->{user}->{pid});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }

    $c->stash->{current_view} = 'JSON';
}

=head2 unassignNodes

=cut

sub unassignNodes :Chained('object') :PathPart('unassignNodes') :Args(0) :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    my ($status, $result) = $self->getModel($c)->unassignNodes($c->stash->{user}->{pid});
    $self->audit_current_action($c, status => $status, pid => $c->stash->{user}->{pid});
    if (is_error($status)) {
        $c->response->status($status);
    }
    $c->stash->{status_msg} = $result;

    $c->stash->{current_view} = 'JSON';
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    my ($form, $status, $message);

    $form = $self->getForm($c, "User", init_object => $c->stash->{user});
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        ($status, $message) = $self->getModel($c)->update($c->stash->{user}->{pid}, $form->value, $c->user);
        $self->audit_current_action($c, status => $status, pid => $c->stash->{user}->{pid});
    }
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 violations

Show violations for user

=cut

sub violations :Chained('object') :PathPart :Args(0) :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    my ($status, $result) = $self->getModel($c)->violations($c->stash->{user}->{pid});
    if (is_success($status)) {
        $c->stash->{items} = $result;
    } else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 nodes

Show nodes for user

=cut

sub nodes :Chained('object') :PathPart :Args(0) :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    my ($status, $result) = $self->getModel($c)->nodes($c->stash->{user}->{pid});
    if (is_success($status)) {
        $c->stash->{nodes} = $result;
    } else {
        $c->response->status($status);
        $c->stash(
            status_msg => $result,
            current_view => 'JSON',
            nodes => [],
        )
    }
    return ;
}

=head2 reset

=cut

sub reset :Chained('object') :PathPart('reset') :Args(0) :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    my ($status, $message) = (HTTP_BAD_REQUEST, 'Some required parameters are missing.');

    if ( $c->request->method eq 'POST' ) {
        my $password = $c->request->params->{password};
        if ($password) {
            ( $status, $message ) = $c->model('DB')->resetUserPassword( $c->stash->{user}->{pid}, $password );
            $self->audit_current_action($c, status => $status, pid => $c->stash->{user}->{pid});
            $c->session->{'users_passwords'} = [ { pid => $c->stash->{user}->{pid}, password => $password } ];
        }
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=head2 create

/user/create

=cut

sub create :Local :AdminRoleAny('USERS_CREATE') :AdminRoleAny('USERS_CREATE_MULITPLE') {
    my ($self, $c) = @_;

    my (@roles, $form, $form_single, $form_multiple, $form_import, $params);
    my ($type, %data, @options);
    my ($status, $result, $message);

    ($status, $result) = $c->model('Config::Roles')->listFromDB();
    if (is_success($status)) {
        @roles = @$result;
    }

    $form = $self->getForm($c, "User::Create", roles => \@roles);
    $form_single = $self->getForm($c, "User::Create::Single");
    $form_multiple = $self->getForm($c, "User::Create::Multiple");
    $form_import = $self->getForm($c, "User::Create::Import");

    if (scalar(keys %{$c->request->params}) > 1) {
        # We consider the request parameters only if we have at least two entries.
        # This is the result of setuping jQuery in "no Ajax cache" mode. See admin/common.js.
        $params = $c->request->params;
    } else {
        $params = {};
    }
    $form->process(params => $params);
    $form_single->process(params => $params);
    $form_multiple->process(params => $params);

    my $skipped;
    if ($c->request->method eq 'POST') {
        $type = $c->request->param('type');
        #check if they can do multiple actions
        unless ($type eq 'single' || admin_can([$c->user->roles], 'USERS_CREATE_MULTIPLE')) {
            $c->response->status(HTTP_UNAUTHORIZED);
            $c->stash->{status_msg}   = "You don't have the rights to perform this action.";
            $c->stash->{current_view} = 'JSON';
            $c->detach();
        }
        # Create new user accounts
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
                ($status, $message) = $self->getModel($c)->createSingle(\%data, $c->user);
                @options = ('mail');
                if ($self->_add_sms_source($c, \%data)) {
                    push @options, 'sms';
                }
                $c->session->{'users_passwords'} = $message;
            }
        }
        elsif ($type eq 'multiple') {
            if ($form_multiple->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_multiple->field_errors;
            }
            else {
                %data = (%{$form->value}, %{$form_multiple->value});
                ($status, $message, $skipped) = $self->getModel($c)->createMultiple(\%data, $c->user);
                $c->session->{'users_passwords'} = $message;
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
                ($status, $message, $skipped) = $self->getModel($c)->importCSV(\%data, $c->user);
                @options = ('mail');
                $c->session->{'users_passwords'} = $message;
            }
        }
        else {
            $status = $STATUS::INTERNAL_SERVER_ERROR;
        }
        $self->audit_current_action($c, status => $status, create_type => $type);

        $c->response->status($status);
        $c->stash->{status} = $status;

        if (is_success($status)) {
            # List the created accounts
            my @pids = map { $_->{pid} } @{$message};
            $c->stash->{users} = $message;
            $c->stash->{skipped} = $skipped if defined($skipped);
            $c->stash->{pids} = \@pids;
            $c->stash->{options} = \@options;
            $c->stash->{template} = 'user/list_password.tt';
        }
        else {
            $c->stash->{status_msg} = $message; # TODO: localize error message
            $c->stash->{template} = 'user/create_error.tt';
            $c->stash->{error_information} = encode_json({status_msg => $message, status => $status});
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
    }
}

=head2 _add_sms_source

Add SMS source information if advanced.source_to_send_sms_when_creating_users is configured

=cut

sub _add_sms_source {
    my ($self, $c, $user) = @_;
    my $sms_source_id = $Config{advanced}{source_to_send_sms_when_creating_users};
    unless ($sms_source_id && $user->{telephone}) {
        return;
    }
    my $sms_source = getAuthenticationSource($sms_source_id);
    unless ($sms_source) {
        return;
    }
    $c->stash->{sms_source} = $sms_source;
    if ($sms_source->can("sms_carriers")) {
        $c->stash->{sms_carriers} = sms_carrier_view_all($sms_source);
    }
    return 1;
}


=head2 advanced_search

Perform advanced search for user
/user/advanced_search

=cut

sub advanced_search :Local :Args() :AdminRoleAny(USERS_READ) :AdminRoleAny(USERS_READ_SPONSORED) {
    my ($self, $c, @args) = @_;
    my ($status, $status_msg, $result);
    my %search_results;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
        $c->stash(current_view => 'JSON');
    }
    else {
        my $query = $form->value;
        ($status, $result) = $model->search($c, $query);
        if (is_success($status)) {
            $c->stash(form => $form);
            $c->stash($result);
        }
        $c->stash(current_view => 'JSON') if ($c->request->params->{'json'});
    }
    my ( $roles, $violations );
    (undef, $roles) = $c->model('Config::Roles')->listFromDB();
    (undef, $violations) = $c->model('Config::Violations')->readAll();
    $c->stash(
        status_msg => $status_msg,
        roles => $roles,
        violations => $violations,
    );

    if($c->request->param('export')) { 
        $c->stash->{current_view} = "CSV";
    }

    $c->response->status($status);
}

=head2 print

Display a printable view of users credentials.

/user/print

=cut

sub print :Local :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    my ($status, $result);
    my @pids = split(/,/, $c->request->params->{pids});
    # we get the created users from the session so we have a copy of the cleartext password
    my %users_passwords_by_pid = map { $_->{'pid'}, $_ } @{ $c->session->{'users_passwords'} };

    ( $status, $result ) = $self->getModel($c)->read( $c, \@pids );
    $self->audit_current_action($c, status => $status, pids => \@pids);

    # we overwrite the password found in the database with the one in the session for the same user
    for my $user (@$result) {
        my $pid = $user->{'pid'};
        if ( exists $users_passwords_by_pid{$pid} ) {
            $user->{'password'} = $users_passwords_by_pid{$pid}->{'password'};
        }
    }

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

sub mail :Local :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    my ($status, $result);
    my @pids = split(/,/, $c->request->params->{pids});

    ($status, $result) = $self->getModel($c)->mail($c, \@pids);
    $self->audit_current_action($c, status => $status, pids => \@pids);

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

=head2 sms

Send users credentials by sms

/user/sms

=cut

sub sms :Local :AdminRole('USERS_UPDATE') {
    my ($self, $c) = @_;

    $c->stash->{current_view} = 'JSON';
    my ($status, $result);
    my @pids = split(/,/, $c->request->params->{pids});

    ($status, $result) = $self->getModel($c)->sms($c, \@pids);
    $self->audit_current_action($c, status => $status, pids => \@pids);

    if (is_success($status)) {
        $c->stash->{status_msg} = $c->loc('An sms was sent to [_1] out of [_2] users.',
                                          scalar @pids, scalar @$result);
    }
    else {
        $c->stash->{status_msg} = $result;
    }

    $c->response->status($status);
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
