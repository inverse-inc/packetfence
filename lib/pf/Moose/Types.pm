package pf::Moose::Types;

=head1 NAME

pf::Moose::Types -

=cut

=head1 DESCRIPTION

pf::Moose::Types

=cut

use strict;
use warnings;
use Moose::Util::TypeConstraints;
use NetAddr::IP;
use pf::util qw(normalize_time);

subtype 'NetAddrIpStr', as 'NetAddr::IP';

coerce 'NetAddrIpStr', from 'Str', via { NetAddr::IP->new($_) };

subtype 'RegexpRefStr', as 'RegexpRef';

coerce 'RegexpRefStr', from 'Str', via {qr/$_/};

subtype 'PfInterval', as 'Int';

coerce 'PfInterval', from 'Str', via { return normalize_time($_) };

no Moose::Util::TypeConstraints;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

