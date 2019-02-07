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

The get_* methods return a string or integer.

The as_* methods return a new pf::MAC object with the given notation as constructor.

=cut

use strict;
use warnings;

use base 'Net::MAC';

use overload
    '""' => sub { return $_[0]->get_mac(); },
    '==' => \&_compare_value,
    '!=' => \&_compare_value_ne,
    'eq' => \&_compare_string,
    'ne' => \&_compare_string_ne;

=head2 clean

Cleans a MAC address. 

Returns an untainted pf::MAC with MAC in format: xx:xx:xx:xx:xx:xx (lowercased).

=cut

sub clean {
    my $self    = shift;
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

=head2 get_stripped

Returns the MAC address stripped of any delimiter (base is preserved).

=cut

sub get_stripped {
    my $self = shift;
    my $mac  = $self->get_mac();
    $mac =~ s/[^[:xdigit:]]//g;
    return $mac;
}

=head2 get_hex_stripped

Returns a string containing the MAC address in hex base, stripped of any delimiter (uppercased).

=cut

sub get_hex_stripped {
    my $self     = shift;
    my $IEEE_mac = $self->as_IEEE->get_mac();
    $IEEE_mac =~ s/[^[:xdigit:]]//g;
    return $IEEE_mac;
}

=head2 get_dec_stripped

Returns a string with the MAC as a decimal without delimiter.

=cut

sub get_dec_stripped {
    my $self = shift;

    # disabling warnings in this scope because a MAC address (48bit) is larger than an int on 32bit systems
    # and perl warns about it but gives the right value.
    no warnings;
    return hex( $self->get_hex_stripped() );
}

=head2 get_oui

Returns the OUI for the MAC as an lowercased hex string with : delimiters.

This is the format PF uses.

=cut

sub get_oui {
    my $self     = shift;
    my $IEEE_mac = $self->as_IEEE() ;
    return substr( lc $IEEE_mac, 0, 8 );
}

=head2 get_IEEE_oui

Returns the OUI for the MAC as an uppercased hex string with - delimiters.

This is the format the IEEE uses.

=cut

sub get_IEEE_oui {
    my $self     = shift;
    my $IEEE_mac = $self->as_Microsoft->get_mac();
    return substr( $IEEE_mac, 0, 8 );
}

=head2 get_dec_oui

Returns a decimal value of the OUI stripped of any delimiters.

=cut

sub get_dec_oui {
    my $self = shift;
    my $oui  = $self->get_oui();
    $oui =~ s/[^[:xdigit:]]//g;
    return hex($oui);
}

=head2 as_oid 

Returns a pf::MAC object with the MAC formatted as an SNMP OID.

example: '00-12-f0-13-32-ba' -> '0.18.240.19.50.186'

=cut

sub as_oid {
    my $self = shift;
    return $self->convert( base => 10, bit_group => 8, delimiter => '.' );
}

=head2 as_acct

Returns an uppercased, hex based and : delimited pf::MAC object (formatted for PacketFence acounting).

=cut

sub as_acct {
    my $self = shift;
    return pf::MAC->new( mac => $self->get_hex_stripped() );
}

=head2 as_Cisco

Returns a new pf::MAC object formatted for Cisco ( example: 0002.03aa.abff ).

Documented here for consistency with the other methods implementing functions from pf::util.

See Net::MAC for implementation.

=cut

#sub as_Cisco {};

=head2 macoui2nb

Provided for backwards compatibility with pf::util::macoui2nb.

Equivalent to get_dec_oui().

=cut 

*macoui2nb = \&get_dec_oui;

=head2 mac2nb

Provided for backwards compatibility with pf::util::mac2nb.

Equivalent to get_dec_stripped().

=cut

*mac2nb = \&get_dec_stripped;

=head2 format_for_acct

Intended for backward compatibility with pf::util::format_mac_for_acct.

Equivalent to as_acct();

=cut 

*format_for_acct = \&as_acct;


=head2 in_OUI

Checks whether a MAC is part of an OUI. It expects the OUI to be passed 
as a string of hexadecimal digits, with or without separators.
Returns 0 or 1.

=cut

sub in_OUI {
    my ($self, $oui) = @_;
    $oui = lc $oui;
    $oui =~ s/[^[:xdigit:]]//g;
    my $internal_oui = substr($self->get_internal_mac,0,6);
    if ( $internal_oui eq $oui ) { return 1; }
    else                         { return 0; }
}

# Operators overloading.
# We need to "over-overload" some of the operators from the parent class (Net::MAC). 
# Specifically, the eq and ne operators differ from the parent. 
# We want them to compre the internal MAC and not the string as passed to the constructor.
# There are too many places in PF relying on that as it is to redefine that behavior.

# Overloading the eq operator (string comparison)
sub _compare_string {
    my ( $arg_1, $arg_2, $reversed ) = @_;
    my ( $mac_1, $mac_2 );
    if ( UNIVERSAL::isa( $arg_2, 'pf::MAC' ) ) {
        $mac_2 = $arg_2->get_internal_mac();
    }
    else {
        my $temp = Net::MAC->new( mac => $arg_2 );
        $mac_2 = $temp->get_internal_mac();
    }
    $mac_1 = $arg_1->get_internal_mac();
    if   ( $mac_1 eq $mac_2 ) { return (1); }
    else                      { return (0); }
}

# Overloading the ne operator (string comparison)
sub _compare_string_ne {
    my ( $arg_1, $arg_2, $reversed ) = @_;
    my ( $mac_1, $mac_2 );
    if ( UNIVERSAL::isa( $arg_2, 'pf::MAC' ) ) {
        $mac_2 = $arg_2->get_internal_mac();
    }
    else {
        my $temp = Net::MAC->new( mac => $arg_2 );
        $mac_2 = $temp->get_internal_mac();
    }
    $mac_1 = $arg_1->get_internal_mac();
    if   ( $mac_1 ne $mac_2 ) { return (1); }
    else                      { return (0); }
}

# Overloading the == operator (numerical comparison)
sub _compare_value {
    my ( $arg_1, $arg_2, $reversed ) = @_;
    my ( $mac_1, $mac_2 );
    if ( UNIVERSAL::isa( $arg_2, 'Net::MAC' ) ) {
        $mac_2 = $arg_2->get_internal_mac();
    }
    else {
        my $temp = Net::MAC->new( mac => $arg_2 );
        $mac_2 = $temp->get_internal_mac();
    }
    $mac_1 = $arg_1->get_internal_mac();
    if   ( $mac_1 eq $mac_2 ) { return (1); }
    else                      { return (0); }
}

# Overloading the != operator (numeric comparison)
sub _compare_value_ne {
    my ( $arg_1, $arg_2 ) = @_;
    if   ( $arg_1 == $arg_2 ) { return (0); }
    else                      { return (1); }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
