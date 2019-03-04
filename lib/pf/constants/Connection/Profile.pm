package pf::constants::Connection::Profile;

=head1 NAME

pf::constants::Connection::Profile - constants for Connection::Profile object

=cut

=head1 DESCRIPTION

pf::constants::Connection::Profile

=cut

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
    $BLOCK_INTERVAL_DEFAULT_VALUE
    $DEFAULT_PROFILE
    $MATCH_STYLE_ALL
    $DEFAULT_ROOT_MODULE
    $PENDING_POLICY
);

our $BLOCK_INTERVAL_DEFAULT_VALUE = '10m';
our $DEFAULT_PROFILE = 'default';
our $MATCH_STYLE_ALL = 'all';
our $DEFAULT_ROOT_MODULE = "default_policy";
our $PENDING_POLICY = "default_pending_policy";

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

