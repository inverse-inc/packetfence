package pf::IPv4;

=head1 NAME

pf::IPv4

=cut

=head1 DESCRIPTION

Object class for handling / managing IPv4 addresses

=cut

use strict;
use warnings;

use Moose;
extends 'pf::IP';

# External libs
use Net::IP;
use Readonly;

# Internal libs
use pf::log;


Readonly our $TYPE => 'ipv4';


has 'ipv4'  => (is => 'rw');


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my ( $maybe_ip, $maybe_cidr ) = split(m!/!, $_[0]);

    return undef unless ( Net::IP::ip_is_ipv4($maybe_ip) );

    $maybe_cidr = mask2cidr($maybe_cidr) if ( defined($maybe_cidr) && ($maybe_cidr !~ /^\d{1,2}$/) );
    undef($maybe_cidr) if ( defined($maybe_cidr) && ( ($maybe_cidr < 0) || ($maybe_cidr > 32) ) );

    return $class->$orig (
        'type'          => $TYPE,
        'ipv4'          => $maybe_ip,
        'prefixLength'  => $maybe_cidr,
        'normalizedIP'  => Net::IP::ip_expand_address($maybe_ip, 4),
    );
};


=head2 is_valid

Checks whether or not, a given IPv4 address is valid

This sub can either be called in a procedural or object way

Takes a pf::IPv4 (object call) or an IPv4 address (procedural call) as parameter

Returns a valid IPv4 address from the pf::IPv4 object on success

Returns undef on failure

=cut

sub is_valid {
    my $self = shift;
    # Allow an object/procedural way of calling this sub (will instantiate an object and then call itself)
    if ( ref($self) ne __PACKAGE__ ) {
        my $name = (split '\:\:', (caller(0))[3])[-1];
        return __PACKAGE__->new($self)->$name();
    }

    return $self->ipv4;
}


=head2 cidr2mask

Transforms a CIDR notation (/XX) to an IPv4 subnet mask (XXX.XXX.XXX.XXX)

Takes a valid CIDR notation as parameter

Returns IPv4 subnet mask on success

Returns undef on failure

=cut

sub cidr2mask {
    my ( $cidr ) = @_;
    # Check if valid CIDR
    return undef unless ( $cidr =~ /^\d{1,2}$/ && ( ($cidr >= 0) && ($cidr <= 32) ) );

    my $bits = "1" x $cidr . "0" x (32 - $cidr);

    return join ".", (unpack 'CCCC', pack("B*", $bits ));
}


=head2 mask2cidr

Transforms an IPv4 subnet mask (XXX.XXX.XXX.XXX) to a CIDR notation (/XX)

Takes a valid IPv4 subnet mask as parameter

Returns CIDR notation on success

Returns undef on failure

=cut

sub mask2cidr {
    my ( $mask ) = @_;
    # Check if valid mask
    return undef unless ( defined($mask) );
    for ( split /\./, $mask ) {
        return undef if ( $_ < 0 || $_ > 255 );
    }

    my @bytes = split /\./, $mask;
    my $cidr = 0;
    for ( @bytes ) {
        my $bits = unpack( "B*", pack( "C", $_ ) );
        $cidr += $bits =~ tr /1/1/;
    }

    return $cidr;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
