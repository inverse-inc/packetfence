package pf::billing::constants;

=head1 NAME

pf::billing::constants - Constants for billing to be used by different billing modules

=cut

=head1 DESCRIPTION

This file is splitted by package and refering to the constants requires you to specify the package.

=cut
use strict;
use warnings;

use Readonly;

=head1 BILLING

General constants used by billing

=over

=cut
package BILLING;

=item paymentProcessingStatus

 error(0)
 success(1)

=cut
Readonly::Scalar our $ERROR     => 0;
Readonly::Scalar our $SUCCESS   => 1;

=item paymentProcessingStatusStrings

Status string as put in the database.

=cut
Readonly::Scalar our $STATUS_PROCESSED_ERROR => 'processed - error';
Readonly::Scalar our $STATUS_PROCESSED_SUCCESS => 'processed - success';

=item error_code 

PacketFence error codes regarding billing.

=cut
Readonly::Scalar our $ERROR_INVALID_FORM => 1;
Readonly::Scalar our $ERROR_CC_VALIDATION => 2;
Readonly::Scalar our $ERROR_PAYMENT_GATEWAY_FAILURE => 3;

=item errors 

An hash mapping error codes to error messages.

=cut
Readonly::Hash our %ERRORS => (
    $ERROR_INVALID_FORM => 'Missing mandatory parameter or malformed entry',
    $ERROR_CC_VALIDATION => 'An error occured while processing your payment. Incorrect credit card informations provided.',
    $ERROR_PAYMENT_GATEWAY_FAILURE => "An error occured while processing you payment. Your credit card has not been charged.",
);

=back

=head1 AUTHORIZE.NET

=over

=cut
package AUTHORIZE_NET;

=item response - response fields from Authorize.net

 reponse_code(1)
 response_reason_text(4)

=cut
Readonly::Scalar our $RESPONSE_CODE         => 1;
Readonly::Scalar our $RESPONSE_REASON_TEXT  => 4;

=item response_code - the overall status of the transaction

 approved(1)
 declined(2)
 error(3)
 held_for_review(4)

=cut
Readonly::Scalar our $APPROVED          => 1;
Readonly::Scalar our $DECLINED          => 2;
Readonly::Scalar our $ERROR             => 3;
Readonly::Scalar our $HELD_FOR_REVIEW   => 4;


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
