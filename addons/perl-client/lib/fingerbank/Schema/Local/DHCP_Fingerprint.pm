package fingerbank::Schema::Local::DHCP_Fingerprint;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::DHCP_Fingerprint';

__PACKAGE__->meta->make_immutable;

1;
