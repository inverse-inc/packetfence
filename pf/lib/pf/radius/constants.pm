package pf::radius::constants;

=head1 NAME

pf::radius::constants - Constants for RADIUS module and custom sub-modules

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut

use strict;
use warnings;
use diagnostics;

use Readonly;

=head1 RADIUS 

=over

=cut
package RADIUS;

=item FreeRADIUS return codes

These constants were extracted from the FreeRADIUS' rlm_perl example.pl. 
Care should be taken to align with upstream since the code returned by our module will be interpreted by FreeRADIUS.

 RLM_MODULE_REJECT: immediately reject the request
 RLM_MODULE_FAIL: module failed, don't reply
 RLM_MODULE_OK: the module is OK, continue
 RLM_MODULE_HANDLED: the module handled the request, so stop.
 RLM_MODULE_INVALID: the module considers the request invalid.
 RLM_MODULE_USERLOCK: reject the request (user is locked out)
 RLM_MODULE_NOTFOUND: user not found
 RLM_MODULE_NOOP: module succeeded without doing anything
 RLM_MODULE_UPDATED: OK (pairs modified)
 RLM_MODULE_NUMCODES: How many return codes there are

=cut

Readonly::Scalar our $RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
Readonly::Scalar our $RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
Readonly::Scalar our $RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
Readonly::Scalar our $RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
Readonly::Scalar our $RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
Readonly::Scalar our $RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
Readonly::Scalar our $RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
Readonly::Scalar our $RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
Readonly::Scalar our $RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
Readonly::Scalar our $RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
