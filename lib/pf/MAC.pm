package pf::MAC;

=head1 NAME

pf::MAC

=head1 DESCRIPTION
pf::MAC implements a class that instantiates MAC addresses objects.
At the moment it is rather minimalist, inheriting from Net::MAC which already does 
90% of what PacketFence needs.

The purpose of this class is to allow us to extend it or later rewrite it without worrying about 
Net::MAC's implementation.

Since passing the Net::MAC object to a function actually passes the string version of the constructors 
initial argument, it should be safe to keps calling things like `mac2oid($mac)'.

=over

=cut

use strict;
use warnings;

use base 'Net::MAC';

1;
