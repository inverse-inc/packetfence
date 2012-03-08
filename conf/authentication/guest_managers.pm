package authentication::guest_managers;
=head1 NAME

authentication::guest_managers - authenticate guest managers

=head1 DESCRIPTION

htaccess style file authentication on the F<conf/guest-managers.conf> file

This module extends pf::web::auth.

=cut
use strict;
use warnings;
use Apache::Htpasswd;
use Log::Log4perl;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE $conf_dir);

our $VERSION = 1.10;

# TODO: regroup authenticate() portion of local and this module in authentication::htaccess 
#       (or even pf::web::auth::htaccess) to prevent code duplication

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown

=cut
our $name = "Guest Management";

=back

=head1 OBJECT METHODS

=over

=item authenticate( $login, $password )

True if successful, false otherwise. 
If unsuccessful errors meant for users are available in getLastError(). 
Errors meant for administrators are logged in F<logs/packetfence.log>.

=cut
sub authenticate {
  my ($this, $username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::guest_managers');

  foreach my $passwdFile ("$conf_dir/guest-managers.conf", "$conf_dir/admin.conf") {

    if (! -r $passwdFile) {
        $logger->error("unable to read password file '$passwdFile'");
        $this->_setLastError('Unable to validate credentials at the moment');
        next;
    }
  
    my $htpasswd = new Apache::Htpasswd({
        passwdFile => $passwdFile,
        ReadOnly   => 1}
    );
    if ($htpasswd->htCheckPassword($username, $password)) {
        return $TRUE;
    }

  }
  $this->_setLastError('Invalid login or password');
  return $FALSE;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
