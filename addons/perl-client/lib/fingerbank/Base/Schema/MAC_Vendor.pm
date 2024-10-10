package fingerbank::Base::Schema::MAC_Vendor;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('mac_vendor');

__PACKAGE__->add_columns(
   "id",
   "name",
   "mac",
   "created_at",
   "updated_at",
);

__PACKAGE__->set_primary_key('id');

# Custom accessor (value) that returns the MAC_Vendor name when called for listing entries
# See L<fingerbank::Base::CRUD::read>
sub value {
    my ( $self ) = @_;
    return $self->name;
}

__PACKAGE__->meta->make_immutable;

1;
