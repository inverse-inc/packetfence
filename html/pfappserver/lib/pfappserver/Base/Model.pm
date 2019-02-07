package pfappserver::Base::Model;

=head1 NAME

pfappserver::Base::Model

=cut

=head1 DESCRIPTION

pfappserver::Base::Model
The base class for the Catalyst Models

=cut

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Model'; }

=head2 idKey

The key of the id attribute

=cut

has idKey => ( is => 'ro', default => 'id');

=head2 itemKey

The key of a single item

=cut

has itemKey => ( is => 'ro', default => 'item');

=head2 itemsKey

The key of the list of items

=cut

has itemsKey => ( is => 'ro', default => 'items');

=head2 configFile

=cut


sub ACCEPT_CONTEXT {
    my ( $self,$c,%args) = @_;
    return $self->new(\%args);
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

