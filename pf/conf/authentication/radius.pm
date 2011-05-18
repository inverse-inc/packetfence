package authentication::radius;

=head1 NAME

authentication::radius - radius authentication

=head1 SYNOPSYS

  use authentication::radius;
  my ( $authReturn, $err ) = authenticate ( $login, $password);

=head1 DESCRIPTION

authentication::radius allows to validate a username/password combination using RADIUS

=head1 DEPENDENCIES

=over

=item * Authen::Radius

=back

=cut
use strict;
use warnings;
use Authen::Radius;

use base ('pf::web::auth');

our $VERSION = 1.00;

=head1 CONFIGURATION AND ENVIRONMENT

Define the variables C<RadiusServer> and C<RadiusSecret> at the top of the module.

=cut
my $RadiusServer = 'localhost';
my $RadiusSecret = 'testing123';

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Optional

=over

=item name

Name displayed on the captive portal dropdown

=back

=cut
my $name = "RADIUS";

=head1 SUBROUTINES

=over

=item * authenticate ($login, $password)

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=cut
sub authenticate {
    my ($this, $username, $password) = @_;
    my $radcheck = new Authen::Radius(
        Host => $RadiusServer, 
        Secret => $RadiusSecret
    );

    if ($radcheck->check_pwd($username, $password)) {
        return (1,0);
    } else {
        return (0,1);
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

