package captiveportal::Controller::User;
use Moose;
use pf::person;

BEGIN { extends 'captiveportal::Base::Controller'; }

sub signup : Local {
    my ($self, $c) = @_;
    my $request = $c->request;
    if ($request->method eq 'POST') {
        $c->forward('validate_new_user');
#        $c->forward(Authenticate => 'login' );
        $c->response->redirect("/authenticate");
        $c->detach;
    }
    else {
        $c->forward('show_new_user');
    }
}

our $ROLE_FOR_LOGIN = 'low_speed';

sub validate_new_user : Private {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $pid = $request->param("username");
    my $email = $pid;
    if(pf::person::person_exist($pid)) {
        $self->_display_error($c, "username $pid already exists\n");
    }
    my $password = $request->param("password");
    my $password_check = $request->param("password_check");
    if($password ne $password_check) {
        $self->_display_error($c, "Passwords do not match");
    }
    my $room_number = $request->param("room_number");
    unless ($room_number) {
        $self->_display_error($c, "Invalid room number");
    }
    my $result = pf::person::person_modify($pid, email => $email, room_number => $room_number);
    unless ($result) {
        $self->_display_error($c, "Unable to create user $pid");
    }
    my @actions = (
        {type => 'set_role', value => $ROLE_FOR_LOGIN},
    );
    my $new_password = pf::password::generate($pid, \@actions, $password);
}

sub _display_error {
    my ($self, $c, $msg) = @_;
    $c->log->error($msg);
    $c->stash(txt_validation_error => $msg);
    $c->detach('show_new_user');
}

sub show_new_user : Private {
    my ($self, $c) = @_;
    $c->stash(
        template => 'new_user.html'
    );
}

=head1 NAME

captiveportal::Controller::Root - Root Controller for captiveportal

=head1 DESCRIPTION

[enter your description here]

=cut

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

__PACKAGE__->meta->make_immutable;

1;
