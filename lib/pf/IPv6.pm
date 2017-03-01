package pf::IPv6;

=head1 NAME

pf::IPv6

=cut

=head1 DESCRIPTION

Object class for handling / managing IPv6 addresses

=cut

use strict;
use warnings;

use Moose;
extends 'pf::IP';

# External libs
use Net::IP;

# Internal libs
use pf::log;


has 'ipv6'  => (is => 'rw');


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my ( $maybe_ip, $maybe_prefix ) = split(m!/!, $_[0]);

    return undef unless ( Net::IP::ip_is_ipv6($maybe_ip) );

    undef($maybe_prefix) if ( defined($maybe_prefix) && ( $maybe_prefix < 0 || $maybe_prefix > 128 ) );

    return $class->$orig (
        'type'          => 'ipv6',
        'ipv6'          => $maybe_ip,
        'prefixLength'  => $maybe_prefix,
        'normalizedIP'  => Net::IP::ip_expand_address($maybe_ip, 6),
    );
};


sub is_valid {
    my $self = shift;
    if ( ref($self) ne __PACKAGE__ ) {
        my $name = (split '\:\:', (caller(0))[3])[-1];
        return __PACKAGE__->new($self)->$name();
    }

    return $self->ipv6;
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
