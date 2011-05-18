package authentication::guest_managers;
=head1 NAME

authentication::guest_managers - file authentication on the conf/guest-managers.conf file

=head1 SYNOPSIS

  use authentication::guest_managers;
  my ( $authReturn, $err ) = authenticate ( $login, $password );

This module extends pf::web::auth

=head1 DEPENDENCIES

=over

=item * Apache::Htpasswd

=item * Log::Log4perl

=item * pf::config

=back

=cut
use strict;
use warnings;
use Apache::Htpasswd;
use Log::Log4perl;

use base ('pf::web::auth');
use pf::config;

our $VERSION = 1.00;

=head1 SUBROUTINES

=over

=item * authenticate( $login, $password )

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=back

=cut
sub authenticate {
  my ($this, $username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::guest_managers');
  my $passwdFile = "$conf_dir/guest-managers.conf";

  if (! -r $passwdFile) {
      $logger->error("unable to read password file '$passwdFile'");
      return (0,2);
  }

  my $htpasswd = new Apache::Htpasswd({
      passwdFile => $passwdFile,
      ReadOnly   => 1}
  );
  if ((!defined($htpasswd->htCheckPassword($username, $password))) 
    or ($htpasswd->htCheckPassword($username, $password) == 0)) {
      return (0,1);
  } else {
      return (1,0);
  }
}

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
