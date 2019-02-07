package pf::constants::node;

=head1 NAME

pf::constants::node - constants for node

=cut

=head1 DESCRIPTION

pf::constants::node

constants for node

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

our @EXPORT_OK = qw(
    $STATUS_REGISTERED
    $STATUS_UNREGISTERED
    $STATUS_PENDING
    %ALLOW_STATUS
    $NODE_DISCOVERED_TRIGGER_DELAY
);
Readonly::Scalar our $STATUS_REGISTERED => 'reg';
Readonly::Scalar our $STATUS_UNREGISTERED => 'unreg';
Readonly::Scalar our $STATUS_PENDING => 'pending';
Readonly::Scalar our $NODE_DISCOVERED_TRIGGER_DELAY => 10000;

Readonly::Hash our %ALLOW_STATUS => (
    $STATUS_REGISTERED   => 1,
    $STATUS_UNREGISTERED => 1,
    $STATUS_PENDING      => 1,
);
 
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

