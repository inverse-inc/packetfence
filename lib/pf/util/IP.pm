package pf::util::IP;

=head1 NAME

pf::util::IP

=cut

=head1 DESCRIPTION

Util class for handling / managing IP addresses

=cut

use strict;
use warnings;

# Extenal libs

# Internal libs
use pf::IPv4;
use pf::IPv6;
use pf::log;


=head2 detect

Detect the type of a given [Maybe]IPv4/IPv6 address and check if it is valid

Returns a pf::IPv4 / pf::IPv6 object depending on the type on success

Returns undef on failure

=cut

sub detect {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger;

    if ( $ip =~ /:/ ) {
        my $ipv6 = pf::IPv6->new($ip);
        return $ipv6 if defined($ipv6->type);
    } else {
        my $ipv4 = pf::IPv4->new($ip);
        return $ipv4 if defined($ipv4->type);
    }

    $logger->warn("Tried to detect type for an invalid IP '$ip'");
    return undef;
}


=head2 is_ipv6

Check if a given [Maybe]IPv6 address is valid

=cut

sub is_ipv6 {
    my ( $maybe_ipv6 ) = @_;
    my $logger = pf::log::get_logger();

    unless ( pf::IPv6::is_valid($maybe_ipv6) ) {
        my $caller = ( caller(1) )[3] || basename($0);
        $caller =~ s/^(pf::\w+|main):://;
        $logger->debug("invalid IPv6: $maybe_ipv6 from $caller");
        return (0);
    }

    return (1);
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

1;
