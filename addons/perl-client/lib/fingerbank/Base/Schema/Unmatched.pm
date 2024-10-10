package fingerbank::Base::Schema::Unmatched;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('unmatched');

__PACKAGE__->add_columns(
   "id",
   "type",
   "value",
   "occurence",
   "created_at",
   "updated_at",
);

__PACKAGE__->set_primary_key('id');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(name => 'idx_type', fields => ['type']);
    $sqlt_table->add_index(name => 'idx_value', fields => ['value']);
}

__PACKAGE__->meta->make_immutable;

1;
