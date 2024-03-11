package pfappserver::Role::Form::RolesAttribute;

=head1 NAME

pfappserver::Role::Form::RolesAttribute -

=cut

=head1 DESCRIPTION

pfappserver::Role::Form::RolesAttribute

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose::Role;
use pf::ConfigStore::Roles;

has roles => ( is => 'rw', builder => '_build_roles');

our @ROLES;

sub _build_roles {
    my ($self) = @_;
    return _get_roles();
}

sub _get_roles {
    unless (@ROLES) {
        my $cs = pf::ConfigStore::Roles->new;
        @ROLES = sort { $a->{name} cmp $b->{name}  } @{$cs->readAll('name')};
    }

    return [@ROLES];
}

sub _clear_roles {
    @ROLES = ();
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

