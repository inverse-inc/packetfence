package pf::constants;
=head1 NAME

pf::constants add documentation

=cut

=head1 DESCRIPTION

pf::constants

=cut

use strict;
use warnings;
use Readonly;
use base qw(Exporter);
our @EXPORT = qw(
    $FALSE $TRUE $YES $NO $default_pid $admin_pid
);
# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $YES => 'yes';
Readonly::Scalar our $NO => 'no';
Readonly::Scalar our $default_pid => 'default';
Readonly::Scalar our $admin_pid => 'admin';

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
