package pf::Switch::Foundry::MC;

=head1 NAME

pf::Switch::Foundry::MC 

=head1 SYNOPSIS

The pf::Switch::Foundry::MC module implements an object oriented interface
to manage Foundry's Mobility Controllers (MC) via Telnet/SSH

=head1 STATUS

Although we have never tested a Foundry Mobility Controller, 
we have reason to believe that it might work with Meru's code as-is.

Please let us know if you have access to such hardware and can validate our claims.

=cut

use strict;
use warnings;

use base ('pf::Switch::Meru');

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

