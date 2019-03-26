package pf::UnifiedApi::Controller::Preferences;

=head1 NAME

pf::UnifiedApi::Controller::Preferences -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Preferences

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::I18N::pfappserver;
use pf::constants;
use pf::error qw(is_success is_error);
use pf::dal::user_preference;

=head2 list

List all preferences for the current user

=cut

sub list {
    my ($self) = @_;

    my $username = $self->get_username();
    return $FALSE unless($username);
    
    my $items = pf::dal::user_preference->search(
        -where => {
            pid => $username,
        }
    )->all(undef);
    $items = [ map { $self->filter_item($_) } @$items ];

    return $self->render(status => 200, json => {items => $items});
}

=head2 filter_item

Filter the values of an item to the ones that should be in the responses

=cut

sub filter_item {
    my ($self, $item) = @_;
    # Remap to keep only ID and value
    return { map {$_ => $item->{$_}} qw(id value) }; 
}

=head2 get_username

Attempt to obtain the username from a request

=cut

sub get_username {
    my ($self) = @_;
    my $username = $self->req->headers->header('X-PacketFence-Username');

    if($username) {
        return $username;
    }
    else{ 
        $self->render_error(404, "Username not present in request");
        return $FALSE;
    }

}

=head2 resource

Find the preference based on current context

=cut

sub resource {
    my ($self) = @_;

    return $TRUE if($self->req->method eq "PUT");

    my $preference_id = $self->stash('preference_id');

    my $username = $self->get_username();
    return $FALSE unless($username);

    (my $status, $self->stash->{preference}) = pf::dal::user_preference->find({pid => $username, id => $preference_id});
    if(is_success($status)) {
        return $TRUE;
    }
    else {
        $self->render_error(404, "Unable to find preference for this user");
    }
}

=head2 get

Get a preference

=cut

sub get {
    my ($self) = @_;

    return $self->render(
        status => 200,
        json => {
            item => $self->filter_item($self->stash('preference')),
        }
    );
}

=head2 replace

Replace a preference

=cut

sub replace {
    my ($self) = @_;

    my $preference_id = $self->stash('preference_id');
    
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        return $self->render_error($status, "Unable to parse JSON body");
    }

    my $username = $self->get_username;
    return unless($username);

    ($status, my $obj) = pf::dal::user_preference->find_or_create({
        pid => $username,
        id => $preference_id,
    });

    if (is_error($status)) {
        return $self->render_error(422, "Unable to replace preference, check server side logs for details.");
    }

    $obj->{value} = $json->{value};

    $status = $obj->save();

    if (is_error($status)) {
        $self->render_error(422, "Unable to save preference $preference_id");
    }
    else {
        $self->render(json => {message => "Updated preference $preference_id"}, status => 200);
    }
}

=head2 delete

Delete a preference

=cut

sub delete {
    my ($self) = @_;

    my ($status) = $self->stash('preference')->remove();

    $self->render(status => $status, json => {});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
