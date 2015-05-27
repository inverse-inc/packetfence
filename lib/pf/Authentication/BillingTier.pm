package pf::Authentication::BillingTier;
=head1 NAME

pf::Authentication::BillingTier add documentation

=cut

=head1 DESCRIPTION

pf::Authentication::BillingTier

=cut

use strict;
use warnings;
use Moose;


=head2 id

=cut

has id => ( is => 'rw', required => 1 );

=head2 name

=cut

has name => ( is => 'rw', required => 1 );

=head2 price

=cut

has price => ( is => 'rw', required => 1 );

=head2 timeout

=cut

has timeout => ( is => 'rw', required => 1 );

=head2 category

=cut

has category => ( is => 'rw', required => 1 );

=head2 description

=cut

has description => ( is => 'rw', required => 1 );

=head2 destination_url

=cut

has destination_url => ( is => 'rw', required => 1 );

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

