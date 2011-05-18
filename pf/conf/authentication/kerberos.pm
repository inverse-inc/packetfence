package authentication::kerberos;
=head1 NAME

authentication::kerberos - kerberos authentication

=head1 SYNOPSYS

  use authentication::kerberos;
  my ( $authReturn, $err ) = authenticate ( $login, $password );

This module extends pf::web::auth

=head1 DESCRIPTION

authentication::kerberos allows to validate a username/password combination using Kerberos5

=cut

use strict;
use warnings;
use Authen::Krb5::Simple;

use base ('pf::web::auth');

our $VERSION = 1.00;

=head1 CONFIGURATION AND ENVIRONMENT

Don't forget to install the Authen::Krb5::Simple module. 
This is done automatically if you use a packaged version of PacketFence.

Define the variables C<Krb5Realm> at the top of the module.

=cut

my $Krb5Realm = 'EXAMPLE.COM';

=head1 SUBROUTINES

=over

=item authenticate ($login, $password)

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=cut

sub authenticate {
    my ($this, $username, $password) = @_;
    my $krb = Authen::Krb5::Simple->new( realm => $Krb5Realm );

    if ($krb->authenticate($username, $password)) {
        return (1,0);
    } else {
        return (0,1);
    }
}

=back

=head1 AUTHOR

Brad Lhotsky <brad@divisionbyzero.net> 

Based on pf::authenticate::radius by:

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
