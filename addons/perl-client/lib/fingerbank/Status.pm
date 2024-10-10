package fingerbank::Status;

=head1 NAME

fingerbank::Status

=head1 DESCRIPTION

HTTP status codes for status handling

=cut

use strict;
use warnings;

use Readonly;

=head1 STATUS CODES

=over

=item $OK

=item $CREATED

=item $NO_CONTENT

=item $BAD_REQUEST

=item $UNAUTHORIZED

=item $FORBIDDEN

=item $NOT_FOUND

=item $PRECONDITION_FAILED

=item $INTERNAL_SERVER_ERROR

=item $NOT_IMPLEMENTED

=cut

Readonly::Scalar our $OK                                => 200;
Readonly::Scalar our $CREATED                           => 201;
Readonly::Scalar our $NO_CONTENT                        => 204;

Readonly::Scalar our $BAD_REQUEST                       => 400;
Readonly::Scalar our $UNAUTHORIZED                      => 401;
Readonly::Scalar our $FORBIDDEN                         => 403;
Readonly::Scalar our $NOT_FOUND                         => 404;
Readonly::Scalar our $PRECONDITION_FAILED               => 412;

Readonly::Scalar our $INTERNAL_SERVER_ERROR             => 500;
Readonly::Scalar our $NOT_IMPLEMENTED                   => 501;

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
