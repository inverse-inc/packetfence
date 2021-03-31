package pf::UnifiedApi::Controller::Tenants;

=head1 NAME

pf::UnifiedApi::Controller::Tenants -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Tenants

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::tenant;
use pf::config::tenant;
use pf::constants qw($DEFAULT_TENANT_ID);
use pf::error qw(is_error);

has dal => 'pf::dal::tenant';
has url_param_name => 'tenant_id';
has primary_key => 'id';

sub can_remove {
    my ($self) = @_;
    if ($self->is_readonly) {
        return (403, 'Cannot remove this resource');
    }

    return $self->SUPER::can_remove;
}

sub can_update {
    my ($self) = @_;
    if ($self->is_readonly) {
        return (403, 'Cannot update this resource');
    }

    return $self->SUPER::can_update;
}

sub can_create {
    my ($self) = @_;
    if ($self->is_readonly) {
        return (403, 'Cannot create this resource');
    }

    return $self->SUPER::can_create;
}

sub do_get {
    my ($self, $data) = @_;
    my ($status, $item) = $self->dal->find($data);
    if (is_error($status)) {
        $item = undef;
    } else {
        $item = $item->to_hash();
        $item->{not_deletable} = $self->not_deletable($item);
    }

    return ($status, $item);
}

sub not_deletable {
    my ($self, $item) = @_;
    if ($item->{id} <= $DEFAULT_TENANT_ID) {
        return $self->json_true;
    }

    return $self->is_readonly ? $self->json_true : $self->json_false;
}

sub is_readonly {
    pf::config::tenant::get_tenant() > $DEFAULT_TENANT_ID
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

