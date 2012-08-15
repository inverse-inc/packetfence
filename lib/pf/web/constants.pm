package pf::web::constants;

=head1 NAME

pf::web::constants - Constants for the captive portal

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut
use strict;
use warnings;

use Readonly;

=head1 SUBROUTINES

=over

=item to_hash

Return all the WEB constants in an hash. This is to ease consumption by
Template Toolkit.

=cut
sub to_hash {
    no strict 'refs';

    # This needs some explanation.
    # Lists all the entries of the WEB package then for each of them it
    # will create an hash entry with the value of the package variable
    # only if it is a scalar.
    return map { $_ => ${"WEB::$_"} if defined ${"WEB::$_"} } keys %WEB::;
}

=back

=head1 WEB

=over

=cut
package WEB;

=item URLs

=cut

Readonly::Scalar our $URL_SIGNUP => '/signup';
Readonly::Scalar our $URL_SIGNUP_UGLY => '/guest-selfregistration.cgi';

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
