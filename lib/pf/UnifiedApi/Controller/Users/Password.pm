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
use pf::nodecategory qw(nodecategory_view);
use pf::password;
use pf::dal::password;
use pf::admin_roles;
has dal => 'pf::dal::password';
has url_param_name => 'user_id';
has primary_key => 'pid';
has 'url_parent_ids' =>  sub { [qw(user_id)] };
has 'parent_primary_key_map' => sub { {user_id => 'pid'} };

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
    $data = $self->_handle_password_data($data);
    if (exists $data->{expiration} && !defined $data->{expiration}) {
        $data->{expiration} = \['DATE_ADD(NOW(), INTERVAL ? SECOND)', $pf::password::EXPIRATION];
    }

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
    if (exists($data->{password})) {
        if(my $algo = $self->req->query_params->to_hash->{password_algorithm}) {
            $data->{password} = pf::password::_hash_password($data->{password}, algorithm => $algo);
        }
        else {
            $data->{password} = pf::password::default_hash_password($data->{password});
        }
    }

    if (exists($data->{access_level})) {
        my $access_level = $data->{access_level};
        if (defined $access_level && ref($access_level) eq 'ARRAY') {
            $data->{access_level} = join(",", @$access_level);
        }
    }

    # Not sure why but currently in the cloudnac, the sponsor field breaks the insert
    # This is a temporary fix, we should figure out why this happens
    $data->{sponsor} = ($data->{sponsor} // "") ne "" ? $data->{sponsor} : 0;

    return $data;
}

=head2 validate

validate

=cut

sub validate {
    my ($self, $json) = @_;
    my $roles = $self->stash->{admin_roles};
    my @errors;
    if (exists $json->{category} && defined $json->{category}) {
        my $nc = nodecategory_view($json->{category});
        if ($nc) {
            my $name = $nc->{name};
            if (!check_allowed_options($roles, 'allowed_roles', $name)) {
                push @errors, { field => 'category', message => "$name is not allowed" };
            }
        }
    }

    if (exists $json->{access_level} && defined $json->{access_level}) {
        my $access_level = $json->{access_level};
        if (!check_allowed_options($roles, 'allowed_access_levels', split(/\s*,\s*/, $access_level))) {
             push @errors, { field => 'access_level', message => "$access_level is not allowed" };
        }
    }

    if (exists $json->{access_duration} && defined $json->{access_duration}) {
        my $access_duration = $json->{access_duration};
        if (!check_allowed_options($roles, 'allowed_access_durations', $access_duration)) {
             push @errors, { field => 'access_duration', message => "$access_duration is not allowed" };
        }
    }

    if (exists $json->{unregdate} && defined $json->{unregdate}) {
        my $unreg_date = $json->{unregdate};
        if (!check_allowed_unreg_date($roles, $unreg_date)) {
            push @errors, { field => 'unregdate', message => "$unreg_date is not allowed" };
        }
    }

    if (@errors) {
        return 422, {message => "Invalid input", errors => \@errors};
    }

    return 200, undef;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

