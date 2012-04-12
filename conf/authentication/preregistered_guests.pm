package authentication::preregistered_guests;
=head1 NAME

authentication::preregistered_guests

=head1 DESCRIPTION

Validates provided credentials against the temporary_password table (local guest accounts)

This module extends pf::web::auth.

=cut
use strict;
use warnings;
use Log::Log4perl;
use POSIX;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE normalize_time %Config);
use pf::temporary_password;

our $VERSION = 1.20;

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown

=cut
our $name = "Guests";

=back

=head1 OBJECT METHODS

=over

=item * authenticate( $login, $password )

True if successful, false otherwise. 
If unsuccessful errors meant for users are available in getLastError(). 
Errors meant for administrators are logged in F<logs/packetfence.log>.

=cut
sub authenticate {
    my ($this, $username, $password) = @_;
    my $logger = Log::Log4perl::get_logger('authentication::preregistered_guests');

    my ($status, $access_duration) = pf::temporary_password::validate_password($username, $password);
    $logger->debug("password validation returned: $status");

    if ($status == $pf::temporary_password::AUTH_SUCCESS) {
        $this->{_accessDuration} = $access_duration;
        return $TRUE;

    } elsif ($status == $pf::temporary_password::AUTH_FAILED_INVALID) {
        $this->_setLastError('Invalid login or password');
        return $FALSE;

    } elsif ($status == $pf::temporary_password::AUTH_FAILED_EXPIRED) {
        $logger->info("authentication of guest $username failed because password is expired");
        $this->_setLastError('This account is expired.');
        return $FALSE;

    } elsif ($status == $pf::temporary_password::AUTH_FAILED_NOT_YET_VALID) {
        $logger->info("authentication of guest $username failed because password is not yet activated");
        $this->_setLastError('This account is not yet activated.');
        return $FALSE;
    }

    $this->_setLastError('Invalid login or password');
    return $FALSE;
}

=item * getNodeAttributes

Return unregdate based on access_duration for the user who just authenticated.

=cut
sub getNodeAttributes {
    my ($this) = @_;

    return (
        unregdate => POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($this->{_accessDuration}))),
        category => $Config{'guests_admin_registration'}{'category'},
    );
}

=item * isAllowedToSponsorGuests

Is the given email allowed to sponsor guest access?

Guest can't sponsor other guests.

=cut
sub isAllowedToSponsorGuests {
    my ($this, $sponsor_email) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->error(q{Guest can't sponsor other guests});
    return $FALSE;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011, 2012 Inverse inc.

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
