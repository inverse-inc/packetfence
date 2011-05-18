package authentication::local;
=head1 NAME

authentication::local - htaccess file authentication

=head1 SYNOPSIS

  use authentication::local;
  my ( $authReturn, $err ) = authenticate ( $login, $password );

=head1 DESCRIPTION

authentication::local allows to validate a username/password
combination using the htaccess file F<conf/user.conf>

=cut

use strict;
use warnings;
use Apache::Htpasswd;
use Log::Log4perl;

use base ('pf::web::auth');
use pf::config;

our $VERSION = 1.00;

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown

=back

=cut
my $name = "Local";

=head1 DEPENDENCIES

=over

=item * Apache::Htpasswd

=item * Log::Log4perl

=item * pf::config

=back

=head1 SUBROUTINES

=over

=item * authenticate( $login, $password )

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=cut
sub authenticate {
  my ($this, $username, $password) = @_;
  my $logger = Log::Log4perl::get_logger('authentication::local');
  my $passwdFile = "$conf_dir/user.conf";

  if (! -r $passwdFile) {
      $logger->error("unable to read password file '$passwdFile'");
      return (0,2);
  }

  my $htpasswd = new Apache::Htpasswd({ passwdFile => $passwdFile, ReadOnly   => 1});
  if ( (!defined($htpasswd->htCheckPassword($username, $password))) 
      or ($htpasswd->htCheckPassword($username, $password) == 0) ) {

      return (0,1);
  } else {
      return (1,0);
  }
}

=item * getName

Returns name as configured

=cut
sub getName {
    my ($this) = @_;
    return $name;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2008-2011 Inverse inc.

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
