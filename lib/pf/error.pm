package pf::error;

=head1 NAME

pf::error - Error codes and related functions

=head1 DESCRIPTION

Error codes constants and related error-handling and reporting utilities.

=cut

use strict;
use warnings;

use Readonly;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(is_success is_error);
}

=head1 SUBROUTINES

=over

=item is_success

Returns a true or false value based on if given error code is considered
a success or not.

=cut

sub is_success {
    my ($code) = @_;
    return 1 if ($code >= 200 && $code < 300);
    return 0;
}

=item is_error

Returns a true or false value based on if given error code is considered
an error or not.

=cut

sub is_error {
    my ($code) = @_;
    return 1 if ($code >= 400 && $code < 600);
    return 0;
}

=back

=cut

package STATUS;

=head1 Status codes

We rely on HTTP status codes for our Web Services and decided to use them
in our Model without the mention of HTTP in front.

Taken from HTTP::Status and stripped. Subject to change.

=over

=cut

=item $OK

=item $CREATED

=item $BAD_REQUEST

=item $FORBIDDEN

=item $NOT_FOUND

=item $PRECONDITION_FAILED

=item $INTERNAL_SERVER_ERROR

=cut

Readonly::Scalar our $OK                                => 200;
Readonly::Scalar our $CREATED                           => 201;
#Readonly::Scalar our $ACCEPTED                         => 202;
#Readonly::Scalar our $NON_AUTHORITATIVE_INFORMATION    => 203;
#Readonly::Scalar our $NO_CONTENT                       => 204;
#Readonly::Scalar our $RESET_CONTENT                    => 205;
#Readonly::Scalar our $PARTIAL_CONTENT                  => 206;
#Readonly::Scalar our $MULTI_STATUS                     => 207;
#Readonly::Scalar our $ALREADY_REPORTED                 => 208;

#Readonly::Scalar our $MULTIPLE_CHOICES                 => 300;
#Readonly::Scalar our $MOVED_PERMANENTLY                => 301;
#Readonly::Scalar our $FOUND                            => 302;
#Readonly::Scalar our $SEE_OTHER                        => 303;
#Readonly::Scalar our $NOT_MODIFIED                     => 304;
#Readonly::Scalar our $USE_PROXY                        => 305;
#Readonly::Scalar our $TEMPORARY_REDIRECT               => 307;

Readonly::Scalar our $BAD_REQUEST                      => 400;
#Readonly::Scalar our $UNAUTHORIZED                     => 401;
#Readonly::Scalar our $PAYMENT_REQUIRED                 => 402;
Readonly::Scalar our $FORBIDDEN                         => 403;
Readonly::Scalar our $NOT_FOUND                         => 404;
#Readonly::Scalar our $METHOD_NOT_ALLOWED               => 405;
#Readonly::Scalar our $NOT_ACCEPTABLE                   => 406;
#Readonly::Scalar our $PROXY_AUTHENTICATION_REQUIRED    => 407;
Readonly::Scalar our $REQUEST_TIMEOUT                  => 408;
Readonly::Scalar our $CONFLICT                         => 409;
#Readonly::Scalar our $GONE                             => 410;
#Readonly::Scalar our $LENGTH_REQUIRED                  => 411;
Readonly::Scalar our $PRECONDITION_FAILED               => 412;
#Readonly::Scalar our $REQUEST_ENTITY_TOO_LARGE         => 413;
#Readonly::Scalar our $REQUEST_URI_TOO_LARGE            => 414;
#Readonly::Scalar our $UNSUPPORTED_MEDIA_TYPE           => 415;
#Readonly::Scalar our $REQUEST_RANGE_NOT_SATISFIABLE    => 416;
#Readonly::Scalar our $EXPECTATION_FAILED               => 417;
#Readonly::Scalar our $I_AM_A_TEAPOT                    => 418;
Readonly::Scalar our $UNPROCESSABLE_ENTITY             => 422;
#Readonly::Scalar our $LOCKED                           => 423;
#Readonly::Scalar our $FAILED_DEPENDENCY                => 424;
#Readonly::Scalar our $NO_CODE                          => 425;
#Readonly::Scalar our $UPGRADE_REQUIRED                 => 426;
Readonly::Scalar our $PRECONDITION_REQUIRED            => 428;
#Readonly::Scalar our $TOO_MANY_REQUESTS                => 429;
#Readonly::Scalar our $REQUEST_HEADER_FIELDS_TOO_LARGE  => 431;
#Readonly::Scalar our $RETRY_WITH                       => 449;

Readonly::Scalar our $INTERNAL_SERVER_ERROR            => 500;
Readonly::Scalar our $NOT_IMPLEMENTED                  => 501;
#Readonly::Scalar our $BAD_GATEWAY                      => 502;
#Readonly::Scalar our $SERVICE_UNAVAILABLE              => 503;
#Readonly::Scalar our $GATEWAY_TIMEOUT                  => 504;
#Readonly::Scalar our $HTTP_VERSION_NOT_SUPPORTED       => 505;
#Readonly::Scalar our $VARIANT_ALSO_NEGOTIATES          => 506;
Readonly::Scalar our $INSUFFICIENT_STORAGE             => 507;
#Readonly::Scalar our $BANDWIDTH_LIMIT_EXCEEDED         => 509;
#Readonly::Scalar our $NOT_EXTENDED                     => 510;
#Readonly::Scalar our $NETWORK_AUTHENTICATION_REQUIRED  => 511;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
