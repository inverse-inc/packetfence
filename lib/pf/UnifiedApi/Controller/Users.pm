package pf::UnifiedApi::Controller::Users;

=head1 NAME

pf::UnifiedApi::Controller::User -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::User

=cut

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';


sub list {
    my ($self) = @_;
    $self->render(json => { items => [], hasMore => \0});
}

sub get {
    my ($self) = @_;
    my $res = $self->res;
    my $user_id = $self->stash('user_id');
    my ($status, $item) = pf::dal::person->find({
        pid => $user_id,
    });
    $res->code($status);
    my $results;
    if ($res->is_error) {
        $results = {};
    }
    else {
        $results = { item => $item->to_hash() };
    }
    return $self->render(json => $results);
}

sub create {
    my ($self) = @_;
    my $req = $self->req;
    my $res = $self->res;
    my $data = $req->json;
    my $status = pf::dal::person->create($data);
    $res->code($status);
    return $self->render(json => {});
}

sub remove {
    my ($self) = @_;
    my $res = $self->res;
    my $user_id = $self->stash('user_id');
    my $status = pf::dal::person->remove_by_id({
        pid => $user_id,
    });
    $res->code($status);
    return $self->render(json => {});
}

=head2 update

update

=cut

sub update {
    my ($self) = @_;
    my $req = $self->req;
    my $res = $self->res;
    my $user_id = $self->stash('user_id');
    my $data = $req->json;
    my ($status, $count) = pf::dal::person->update_items(
        -where => {
            pid => $user_id,
        },
        -set => {
            %$data,
        },
        -limit => 1,
    );
    if ($count == 0) {
        $status = 404;
    }
    $res->code($status);
    if ($res->is_error) {

    }
    return $self->render(json => {});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

