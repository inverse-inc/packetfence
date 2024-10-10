package fingerbank::Schema::Local::DHCP6_Fingerprint;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::DHCP6_Fingerprint';

__PACKAGE__->meta->make_immutable;

1;
