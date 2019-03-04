package pfappserver::Model::Config::Profile;

=head1 NAME

pfappserver::Model::Config::Profile add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Profile

=cut

use Moose;
use namespace::autoclean;
use pf::ConfigStore::Profile;

extends 'pfappserver::Base::Model::Config';

=head1 METHODS

=head2 _buildCachedConfig

=cut

has '+configStoreClass' => (default => 'pf::ConfigStore::Profile');

=head2 remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    if ($id eq 'default') {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
    }
    return $self->SUPER::remove($id);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

