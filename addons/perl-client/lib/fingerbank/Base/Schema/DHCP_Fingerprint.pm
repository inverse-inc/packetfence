package fingerbank::Base::Schema::DHCP_Fingerprint;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('dhcp_fingerprint');

__PACKAGE__->add_columns(
   "id",
   "value",
   "created_at",
   "updated_at",
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->meta->make_immutable;

1;
