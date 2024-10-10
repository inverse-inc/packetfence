package fingerbank::Base::Schema::Device;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('device');

__PACKAGE__->add_columns(
   "id",
   "name",
   "mobile",
   "tablet",
   "created_at",
   "updated_at",
   "parent_id",
   "inherit",
   "submitter_id",
   "approved",
);

__PACKAGE__->set_primary_key('id');

# Custom accessor (value) that returns the Device name when called for listing entries
# See L<fingerbank::Base::CRUD::read>
sub value {
    my ( $self ) = @_;
    return $self->name;
}

__PACKAGE__->meta->make_immutable;

1;
