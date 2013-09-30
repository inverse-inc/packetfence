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

The get_* methods are idempotent. They do not modify the object.
The as_* methods return a new pf::MAC object with the given notation as constructor.

=over

=cut

use strict;
use warnings;

use base 'Net::MAC';

=item clean

Cleans a MAC address. 
Returns an untainted pf::MAC with MAC in format: XX:XX:XX:XX:XX:XX (uppercased).

=cut
sub clean {
    my $self = shift;
    my $hex_mac = $self->as_IEEE();

    # untaint $hex_mac
    ($hex_mac) = $hex_mac->get_mac() =~ 
        /^(                         # $1 is whole address between ^ and $
        ([[:xdigit:]]{2}:){5}       # 5 pairs of hex digits delimited by :
        [[:xdigit:]]{2})$           # final pair of xdigits
        /x;
    my $new_mac = pf::MAC->new( mac => lc $hex_mac );
    return $new_mac;
}

=item get_stripped
Returns the MAC address stripped of any delimiter.

=cut
sub get_stripped {
    my $self = shift;
    my $mac = $self->get_mac();
    $mac =~ s/[^[:xdigit:]]//g;
    return $mac;
}

=item get_hex_stripped
Returns a string containing the MAC address in hex base, stripped of any delimiter (uppercased).

=cut
sub get_hex_stripped {
    my $self = shift;
    my $IEEE_mac = $self->as_IEEE()->get_mac();
    $IEEE_mac =~ s/[^[:xdigit:]]//g;
    return $IEEE_mac;
}

=item format_for_acct
Returns an uppercased, hex based and : delimited pf::MAC object.
Intended for backward compatibility with pf::util::format_mac_for_acct.

=cut 
sub format_for_acct {
    my $self = shift;
    return pf::MAC->new( mac => $self->get_hex_stripped() );
}


1;
