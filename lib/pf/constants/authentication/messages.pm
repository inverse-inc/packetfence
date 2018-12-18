package pf::constants::authentication::messages;

=head1 NAME

pf::constants::authentication::messages - constants for authentication object result messages

=cut

=head1 DESCRIPTION

pf::constants::authentication::messages

=cut

use strict;
use warnings;
use Readonly;
use base qw(Exporter);
our @EXPORT = qw(
  $COMMUNICATION_ERROR_MSG $AUTH_FAIL_MSG $AUTH_SUCCESS_MSG $INVALID_EMAIL_MSG $LOCALDOMAIN_EMAIL_UNAUTHORIZED $EMAIL_UNAUTHORIZED
);

Readonly our $COMMUNICATION_ERROR_MSG => 'Unable to validate credentials at the moment';
Readonly our $AUTH_FAIL_MSG => 'Invalid login or password';
Readonly our $AUTH_SUCCESS_MSG => 'Authentication successful.';
Readonly our $INVALID_EMAIL_MSG => 'Invalid e-mail address';
Readonly our $LOCALDOMAIN_EMAIL_UNAUTHORIZED => "You can't register as a guest with this corporate email address. Please register as a regular user using your email address instead.";
Readonly our $EMAIL_UNAUTHORIZED => "Cannot register with this email address: unallowed domain.";

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

