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

sub filter_item {
    my ($self, $item) = @_;
    # Remap to keep only ID and value
    return { map {$_ => $item->{$_}} qw(id value) }; 
}

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

sub get {
    my ($self) = @_;

    return $self->render(
        status => 200,
        json => {
            item => $self->filter_item($self->stash('preference')),
        }
    );
}

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
