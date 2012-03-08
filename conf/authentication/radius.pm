package authentication::radius;
=head1 NAME

authentication::radius - radius authentication

=head1 DESCRIPTION

authentication::radius allows to validate a username/password combination using RADIUS

=cut
use strict;
use warnings;

use Authen::Radius;
use Log::Log4perl;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE);

our $VERSION = 1.10;

=head1 CONFIGURATION AND ENVIRONMENT

Define the C<radiusServers> variable at the top of the module.

=over

=item Servers are always validated from top to bottom.

=item Multiple servers are useful for fault tolerance not to try users on different RADIUS

=back

=cut

# uncomment the second line to add another server to the list to check
# you can add more lines also
my $radiusServers = [ 
    { 'host' => 'server1:1819', secret => 'secret' },
#    { 'host' => 'server2:1819', secret => 'secret2' },
];

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
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    foreach my $server (@$radiusServers) {

        my $radcheck = new Authen::Radius(
            Host => $server->{'host'}, 
            Secret => $server->{'secret'},
        );

        my $response = $radcheck->check_pwd($username, $password);
        if (Authen::Radius::get_error() eq 'ENONE') {

            if ($response) {
                return $TRUE;
            } else {
                $this->_setLastError('Invalid login or password');
                return $FALSE;
            }
        }
    }

    $logger->error("Unable to perform RADIUS authentication on any server: " . Authen::Radius::get_error() );
    $this->_setLastError('Unable to authenticate successfully');
    return $FALSE;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Maikel van der roest <mvdroest@utelisys.com>

=head1 COPYRIGHT

Copyright (C) 2011, 2012 Inverse inc.

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

