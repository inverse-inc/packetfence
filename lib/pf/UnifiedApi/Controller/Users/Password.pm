package pf::UnifiedApi::Controller::Users::Password;

=head1 NAME

pf::UnifiedApi::Controller::Users::Password -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Users::Password

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::password;
has dal => 'pf::dal::password';
has url_param_name => 'user_id';
has primary_key => 'pid';
has 'url_parent_ids' =>  sub { [qw(user_id)] };

=head2 cleanup_item

Remove the password field from the item

=cut

sub cleanup_item {
    my ($self, $item) = @_;
    delete $item->{password};
    $item = $self->SUPER::cleanup_item($item);
    return $item;
}

sub make_create_data {
    my ($self) = @_;
    my ($status, $data) = $self->SUPER::make_create_data();
    $data->{pid} = $self->stash->{user_id};
    $data = $self->_handle_password_data($data);
    return ($status, $data);
}

sub update_data {
    my ($self) = @_;
    my $data = $self->SUPER::update_data();
    $data = $self->_handle_password_data($data);
    return $data;
}

sub _handle_password_data {
    my ($self, $data) = @_;
    if(exists($data->{password})) {
        if(my $algo = $self->req->query_params->to_hash->{password_algorithm}) {
            $data->{password} = pf::password::_hash_password($data->{password}, algorithm => $algo);
        }
        else {
            $data->{password} = pf::password::default_hash_password($data->{password});
        }
    }
    return $data;
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

