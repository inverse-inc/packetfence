package authentication::preregistered_guests;

=head1 NAME

authentication::preregistered_guests

=head1 SYNOPSIS

  use authentication::preregistered_guests;
  my ( $authReturn, $err, $return ) = authenticate ( $login, $password );

=head1 DESCRIPTION

Validates provided credentials against the temporary_password table (local guest accounts)

=cut

use strict;
use warnings;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(authenticate);
}

use Log::Log4perl;

use pf::config;
use pf::temporary_password;

=head1 SUBROUTINES

=over

=item * authenticate( $login, $password )

  return (1, 0, hashref) for successfull authentication
  return (0, 1) for wrong username / password
  return (0, 2) for inability to check credentials
  return (0, 3) credentials expired
  return (0, 4) credntials not yet valid

returned hashref
  access_duration => access_duration value as defined in temporary table

=back

=cut
sub authenticate {
    my ($username, $password) = @_;
    my $logger = Log::Log4perl::get_logger('authentication::preregistered_guests');

    my ($status, $access_duration) = pf::temporary_password::validate_password($username, $password);
    $logger->debug("password validation returned: $status");

    if ($status == $pf::temporary_password::AUTH_SUCCESS) {
        return (1, 0, { 'access_duration' => $access_duration } );
    } elsif ($status == $pf::temporary_password::AUTH_FAILED_INVALID) {
        return (0, 1);
    } elsif ($status == $pf::temporary_password::AUTH_FAILED_EXPIRED) {
        return (0, 3);
    } elsif ($status == $pf::temporary_password::AUTH_FAILED_NOT_YET_VALID) {
        return (0, 4);
    }

    return (0, 2);
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
