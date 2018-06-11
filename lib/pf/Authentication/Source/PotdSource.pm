package pf::Authentication::Source::PotdSource;

=head1 NAME

pf::Authentication::Source::PotdSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Source::SQLSource;
use pf::constants;
use pf::password;
use pf::constants qw($TRUE $FALSE);

use Moose;
extends 'pf::Authentication::Source::SQLSource';

has '+type' => ( default => 'Potd' );
has 'user' => (isa => 'Str', is => 'rw', required => 1);
has 'password_rotation' => (isa => 'Str', is => 'rw', default => '1D');
has 'password_email_update' => (isa => 'Maybe[Str]', is => 'rw');

=head2 authenticate

=cut

sub authenticate {
   my ( $self, $username, $password ) = @_;

   my $result = pf::password::validate_password($username, $password);

   if ($result == $pf::password::AUTH_SUCCESS) {
     return ($TRUE, $AUTH_SUCCESS_MSG);
   }

   return ($FALSE, $AUTH_FAIL_MSG);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


