package pf::trap;
=head1 NAME

pf::trap add documentation

=cut

=head1 DESCRIPTION

pf::trap

=cut

use strict;
use warnings;
use Moo;
use List::Util qw(first);
our $IFINDEX_OID = '.1.3.6.1.2.1.2.2.1.1';

=head2 switch

switch for the trap

=cut

has 'switch' => (is => 'rw');

=head2 trapInfo

The trapInfo from the parse trap

=cut

has 'trapInfo' => (is => 'rw');

=head2 oids

The oids from the parse trap

=cut

has 'oids' => (is => 'rw');

=head2 supportedOIDS

The supported oids for the trap

=cut

sub supportedOIDS { }

=head2 ifIndex

ifIndex

=cut

sub ifIndex {
    my ($self) = @_;
    my $oids = $self->oids;
    my $ifIndexOid = first {  index($_->[0],$IFINDEX_OID) == 0 } @$oids;
    return unless $ifIndexOid;
    return unless $ifIndexOid->[0] =~ /^\Q$IFINDEX_OID\E\.([0-9]+)/;
    return $1;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

