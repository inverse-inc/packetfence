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


sub is_valid {
    my $self = shift;
    if ( ref($self) ne __PACKAGE__ ) {
        my $name = (split '\:\:', (caller(0))[3])[-1];
        return __PACKAGE__->new($self)->$name();
    }

    return $self->ipv4;
}


sub cidr2mask {
    my ( $cidr ) = @_;
    # Check if valid CIDR
    return undef unless ( $cidr =~ /^\d{1,2}$/ && ( ($cidr >= 0) && ($cidr <= 32) ) );

    my $bits = "1" x $cidr . "0" x (32 - $cidr);

    return join ".", (unpack 'CCCC', pack("B*", $bits ));
}


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

Copyright (C) 2005-2017 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
