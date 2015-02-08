package pf::profile::filter::network;
=head1 NAME

pf::profile::filter::network - network filter for profiles

=cut

=head1 DESCRIPTION

pf::profile::filter::network

=cut

use strict;
use warnings;
use Moo;
extends 'pf::profile::filter';
use NetAddr::IP;
use Scalar::Util 'blessed';

=head1 ATTRIBUTES

=head2 value

The NetAddr::IP network to match against

=cut

has '+value' => (
    coerce   => sub {
        # create the object if the attribute can't run()
        blessed($_[0]) && $_[0]->isa('NetAddr::IP')
          ? $_[0]
          : NetAddr::IP->new($_[0])
    },
);

=head1 METHODS

=head2 match

match the last ip to see if it is in defined network

=cut

sub match {
    my ($self,$data) = @_;
    my $last_ip = $data->{last_ip} if exists $data->{last_ip};
    return defined $last_ip && $self->value->contains(NetAddr::IP->new($last_ip));
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

