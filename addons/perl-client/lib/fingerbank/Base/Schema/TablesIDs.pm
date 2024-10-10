package fingerbank::Base::Schema::TablesIDs;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('tables_ids');

__PACKAGE__->add_columns(
   "combination",
   "device",
   "dhcp_fingerprint",
   "dhcp_vendor",
   "dhcp6_fingerprint",
   "dhcp6_enterprise",
   "mac_vendor",
   "user_agent",
);

__PACKAGE__->meta->make_immutable;

1;
