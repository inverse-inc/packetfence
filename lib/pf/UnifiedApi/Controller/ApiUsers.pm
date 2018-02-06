package pf::UnifiedApi::Controller::ApiUsers;

=head1 NAME

pf::UnifiedApi::Controller::ApiUser -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::ApiUser

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::api_user;
use pf::error qw(is_error);

has dal => 'pf::dal::api_user';
has id_key => 'user_id';
has primary_key => 'username';

sub make_create_data {
    my ($self) = @_;
    my ($status, $data) = $self->SUPER::make_create_data();
    if (is_error($status)) {
        return ($status, $data);
    }
    $data->{'-no_auto_tenant_id'} = 1;
    return ($status, $data);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

