package fingerbank::Base::Schema::User_Agent;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('user_agent');

__PACKAGE__->add_columns(
   "id",
   "value",
   "created_at",
   "updated_at",
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->meta->make_immutable;

1;
