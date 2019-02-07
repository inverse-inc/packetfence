package pf::web::guest::constants;

=head1 NAME

pf::web::guest::constants -

=cut

=head1 DESCRIPTION

pf::web::guest::constants

=cut

=head1 ERROR STRINGS

=over

=cut

package GUEST;
use Readonly;

=item error_code

PacketFence error codes regarding guests.

=cut

Readonly::Scalar our $ERROR_INVALID_FORM => 1;
Readonly::Scalar our $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => 2;
Readonly::Scalar our $ERROR_CONFIRMATION_EMAIL => 3;
Readonly::Scalar our $ERROR_CONFIRMATION_SMS => 4;
Readonly::Scalar our $ERROR_MISSING_MANDATORY_FIELDS => 5;
Readonly::Scalar our $ERROR_ILLEGAL_EMAIL => 6;
Readonly::Scalar our $ERROR_ILLEGAL_PHONE => 7;
Readonly::Scalar our $ERROR_AUP_NOT_ACCEPTED => 8;
Readonly::Scalar our $ERROR_SPONSOR_NOT_FROM_LOCALDOMAIN => 9;
Readonly::Scalar our $ERROR_SPONSOR_UNABLE_TO_VALIDATE => 10;
Readonly::Scalar our $ERROR_SPONSOR_NOT_ALLOWED => 11;
Readonly::Scalar our $ERROR_PREREG_NOT_ALLOWED => 12;
Readonly::Scalar our $ERROR_INVALID_PIN => 13;
Readonly::Scalar our $ERROR_MAX_RETRIES => 14;
Readonly::Scalar our $ERROR_EXPIRED_PIN => 15;

=item errors

An hash mapping error codes to error messages.

=cut

Readonly::Hash our %ERRORS => (
    $ERROR_INVALID_FORM => 'Missing mandatory parameter or malformed entry',
    $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => q{You can't register as a guest with a %s email address. Please register as a regular user using your email address instead.},
    $ERROR_CONFIRMATION_EMAIL => 'An error occured while sending the confirmation email.',
    $ERROR_CONFIRMATION_SMS => 'An error occured while sending the PIN by SMS.',
    $ERROR_MISSING_MANDATORY_FIELDS => 'Missing mandatory parameter(s): %s',
    $ERROR_ILLEGAL_EMAIL => 'Illegal email address provided',
    $ERROR_ILLEGAL_PHONE => 'Illegal phone number provided',
    $ERROR_AUP_NOT_ACCEPTED => 'Acceptable Use Policy (AUP) was not accepted',
    $ERROR_SPONSOR_NOT_FROM_LOCALDOMAIN => 'Your access can only be sponsored by a %s email address',
    $ERROR_SPONSOR_UNABLE_TO_VALIDATE => 'Unable to validate your sponsor at the moment',
    $ERROR_SPONSOR_NOT_ALLOWED  => 'Email %s is not allowed to sponsor guest access',
    $ERROR_PREREG_NOT_ALLOWED  => 'Guest pre-registration is not allowed by policy',
    $ERROR_INVALID_PIN => 'PIN is Invalid!',
    $ERROR_MAX_RETRIES => 'Maximum amount of retries attempted',
    $ERROR_EXPIRED_PIN => "PIN has expired!",
);

=back

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
