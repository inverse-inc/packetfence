package pf::Switch::Generic;

=head1 NAME

pf::Switch::Generic

=head1 SYNOPSIS

Implements a generic switch which supports RADIUS MAB + 802.1x in wired + wireless

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;

=head1 SUBROUTINES

=over

=cut

# Description
sub description { return "Generic" }

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
