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

