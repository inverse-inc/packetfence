package authentication::local;
=head1 NAME

authentication::local - htaccess file authentication

=head1 DESCRIPTION

authentication::local allows to validate a username/password combination using the htaccess file F<conf/user.conf>

This module extends pf::web::auth

=cut
use strict;
use warnings;
use Apache::Htpasswd;
use Log::Log4perl;

use base ('pf::web::auth');

use pf::config qw($TRUE $FALSE $conf_dir);

our $VERSION = 1.20;

=head1 CONFIGURATION AND ENVIRONMENT

=over

=item Password file

Defaults to conf/user.conf.

=cut
our $password_file = "$conf_dir/user.conf";

=back

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown (displayed only if more than 1 auth type is configured).

=cut
our $name = "Local";

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
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  if (! -r $password_file) {
      $logger->error("unable to read password file '$password_file'");
      $this->_setLastError('Unable to validate credentials at the moment');
      return $FALSE;
  }

  my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
  if ( (!defined($htpasswd->htCheckPassword($username, $password))) 
      or ($htpasswd->htCheckPassword($username, $password) == 0) ) {

      $this->_setLastError('Invalid login or password');
      return $FALSE;
  } else {
      return $TRUE;
  }
}

=item isAllowedToSponsorGuests

Is the given email allowed to sponsor guest access?

Here we strip the domain portion and validate if the user exists in conf/user.conf.

=cut
sub isAllowedToSponsorGuests {
    my ($this, $sponsor_email) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    if (! -r $password_file) {
        $logger->error("unable to read password file '$password_file'");
        return $FALSE;
    }

    # strip @domain...
    $sponsor_email =~ s/@.*$//;

    # does the user exists in the password file?
    my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
    return $TRUE if ( $htpasswd->fetchPass($sponsor_email) );

    # otherwise
    $logger->error("unable to find user $sponsor_email in password file '$password_file'");
    return $FALSE;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Inverse inc.

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
