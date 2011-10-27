package authentication::radius;
=head1 NAME

authentication::radius - radius authentication

=head1 DESCRIPTION

authentication::radius allows to validate a username/password combination using RADIUS

=cut
use strict;
use warnings;
use Authen::Radius;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE);

our $VERSION = 1.10;

=head1 CONFIGURATION AND ENVIRONMENT

Don't forget to install the Authen::Radius module. 
This is done automatically if you use a packaged version of PacketFence.

Define the variables C<RadiusServer> and C<RadiusSecret> at the top of the module.

=cut
my $RadiusServer = 'localhost';
my $RadiusSecret = 'testing123';

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown

=cut
our $name = "RADIUS";

=back

=head1 OBJECT METHODS

=over

=item * authenticate ($login, $password)

True if successful, false otherwise. 
If unsuccessful errors meant for users are available in getLastError(). 
Errors meant for administrators are logged in F<logs/packetfence.log>.

=cut
sub authenticate {
    my ($this, $username, $password) = @_;
    my $radcheck = new Authen::Radius(
        Host => $RadiusServer, 
        Secret => $RadiusSecret
    );

    if ($radcheck->check_pwd($username, $password)) {
        return $TRUE;
    } else {
        $this->_setLastError('Invalid login or password');
        return $FALSE;
    }
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Maikel van der roest <mvdroest@utelisys.com>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

Copyright (C) 2008 Utelisys Communications B.V.

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

