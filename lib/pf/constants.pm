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
    $FALSE $TRUE $YES $NO $default_pid $admin_pid $BLUE_COLOR $YELLOW_COLOR $RED_COLOR $GREEN_COLOR $CYAN_COLOR $MAGENTA_COLOR
    $HTTP $HTTPS $HTTP_PORT $HTTPS_PORT $ZERO_DATE $SPACE $SPACE_NUMBERS $DEFAULT_TENANT_ID
);

# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $YES => 'yes';
Readonly::Scalar our $NO => 'no';
Readonly::Scalar our $default_pid => 'default';
Readonly::Scalar our $admin_pid => 'admin';
Readonly::Scalar our $YELLOW_COLOR => 'yellow';
Readonly::Scalar our $RED_COLOR => 'red';
Readonly::Scalar our $GREEN_COLOR => 'green';
Readonly::Scalar our $BLUE_COLOR => 'blue';
Readonly::Scalar our $CYAN_COLOR => 'cyan';
Readonly::Scalar our $MAGENTA_COLOR => 'magenta';
Readonly::Scalar our $ZERO_DATE => '0000-00-00 00:00:00';
Readonly::Scalar our $SPACE => q{ };
Readonly::Scalar our $SPACE_NUMBERS => 4;

Readonly::Hash our %BUILTIN_USERS => (
    $default_pid => 1, 
    $admin_pid => 1,
);

Readonly::Scalar our $HTTP_PORT => 80;
Readonly::Scalar our $HTTPS_PORT => 443;

Readonly::Scalar our $HTTP => "http";
Readonly::Scalar our $HTTPS => "https";

Readonly::Scalar our $DEFAULT_TENANT_ID => 1;

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
