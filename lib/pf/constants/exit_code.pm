package pf::constants::exit_code;
=head1 NAME

pf::constants::exit_code

=cut

=head1 DESCRIPTION

pf::constants::exit_code

Constants for all exit code for packect fence

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;
our @EXPORT_OK = qw($EXIT_SUCCESS $EXIT_FAILURE $EXIT_SERVICES_NOT_STARTED $EXIT_FATAL);

=head1 EXIT CODES

=head2 $EXIT_SUCCESS

Success

=cut

Readonly::Scalar our $EXIT_SUCCESS => 0;

=head2 $EXIT_FAILURE

General failure

=cut

Readonly::Scalar our $EXIT_FAILURE => 1;

=head2 $EXIT_FAILURE

General failure

=cut

Readonly::Scalar our $EXIT_SERVICES_NOT_STARTED => 3;

=head2 $EXIT_FATAL

fatal error

=cut

Readonly::Scalar our $EXIT_FATAL => 255;

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

