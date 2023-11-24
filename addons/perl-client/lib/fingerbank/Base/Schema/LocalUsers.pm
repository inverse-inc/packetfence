package fingerbank::Base::Schema::LocalUsers;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('users');

__PACKAGE__->add_columns(
    "id",
    "username",
    "password",
    "encryption",
    "firstname",
    "lastname",
    "email",
    "notes",
    "created_at",
    "updated_at",
    "created_by",
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->meta->make_immutable;

1;
