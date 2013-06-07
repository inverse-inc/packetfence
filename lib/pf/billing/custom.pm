package pf::billing::custom;

=head1 NAME

pf::billing::custom - Object oriented module for billing purposes

=cut

=head1 DESCRIPTION

pf::billing::custom is a module that implements billing functions that are custom to a particular setup.
This module extends pf::billing

=cut

use strict;
use warnings;

use Log::Log4perl;

use base ('pf::billing');

our $VERSION = 1.00;

=head1 SUBROUTINES

=over

=cut

sub getAvailableTiers {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my %tiers = (
            tier1 => {
                id => "tier1", name => "Tier 1", price => "1.00", timeout => "1D", category => 'default',
                description => "Tier 1 Internet Access", destination_url => "http://www.packetfence.org" },
#            tier2 => {
#                id => "tier2", name => "Tier 2", price => "2.00", timeout => "2D", category => 'medium',
#                description => "Tier 2 Internet Access", destination_url => "http://www.inverse.ca" },
#            tier3 => {
#                id => "tier3", name => "Tier 3", price => "3.00", timeout => "3D", category => 'fast',
#                description => "Tier 3 Internet Access", destination_url => "http://www.sogo.nu" },
    );

    return %tiers;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
