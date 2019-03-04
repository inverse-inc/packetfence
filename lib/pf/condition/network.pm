package pf::condition::network;

=head1 NAME

pf::condition::network - check if a value is inside a network

=cut

=head1 DESCRIPTION

pf::condition::network

=cut

use strict;
use warnings;
use Moose;
use pf::Moose::Types;
extends 'pf::condition';
use pf::log;
use pf::constants;

our $logger = get_logger();

=head1 ATTRIBUTES

=head2 value

The IP network to match against

=cut

has 'value' => (
    is       => 'ro',
    required => 1,
    isa => 'NetAddrIpStr',
    coerce => 1,
);

=head1 METHODS

=head2 match

match the last ip to see if it is in defined network

=cut

sub match {
    my ($self, $ip) = @_;
    return $FALSE unless defined $ip;

    my $ip_addr = eval { NetAddr::IP->new($ip) };
    unless (defined $ip_addr) {
        $logger->info("'$ip' is not a valid ip address or range");
        return $FALSE;
    }
    return $self->value->contains($ip_addr);
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
