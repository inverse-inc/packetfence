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
    $FALSE $TRUE $YES $NO $default_pid $admin_pid $WARNING_COLOR $ERROR_COLOR $SUCCESS_COLOR
    $HTTP $HTTPS $HTTP_PORT $HTTPS_PORT
);

# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $YES => 'yes';
Readonly::Scalar our $NO => 'no';
Readonly::Scalar our $default_pid => 'default';
Readonly::Scalar our $admin_pid => 'admin';
Readonly::Scalar our $WARNING_COLOR => 'yellow';
Readonly::Scalar our $ERROR_COLOR => 'red';
Readonly::Scalar our $SUCCESS_COLOR => 'green';

Readonly::Hash our %BUILTIN_USERS => (
    $default_pid => 1, 
    $admin_pid => 1,
);

Readonly::Scalar our $HTTP_PORT => 80;
Readonly::Scalar our $HTTPS_PORT => 443;

Readonly::Scalar our $HTTP => "http";
Readonly::Scalar our $HTTPS => "https";

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
