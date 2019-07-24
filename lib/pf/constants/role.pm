package pf::constants::role;

=head1 NAME

pf::constants::role - constants for roles

=cut

=head1 DESCRIPTION

pf::constants::role

=cut

use strict;
use warnings;
use Readonly;

use Exporter qw(import);

our @EXPORT_OK = qw(
    @ROLES
    %STANDARD_ROLES
    $REGISTRATION_ROLE
    $ISOLATION_ROLE
    $INLINE_ROLE
    $VOICE_ROLE
    $DEFAULT_ROLE
    $GUEST_ROLE
    $GAMING_ROLE
    $REJECT_ROLE
    $POOL_USERNAMEHASH
    $POOL_RANDOM
    $POOL_ROUND_ROBBIN
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

=head2 ROLES

Required roles for every switch. Those are reserved words for any additional custom role.

=cut

Readonly::Scalar our $REGISTRATION_ROLE  => 'registration';
Readonly::Scalar our $ISOLATION_ROLE     => 'isolation';
Readonly::Scalar our $INLINE_ROLE        => 'inline';
Readonly::Scalar our $VOICE_ROLE         => 'voice';
Readonly::Scalar our $DEFAULT_ROLE       => 'default';
Readonly::Scalar our $GUEST_ROLE         => 'guest';
Readonly::Scalar our $GAMING_ROLE        => 'gaming';
Readonly::Scalar our $REJECT_ROLE        => 'REJECT';

Readonly::Array our @ROLES => (
    $REGISTRATION_ROLE,
    $ISOLATION_ROLE,
    $INLINE_ROLE,
);

Readonly::Hash our %STANDARD_ROLES => (
    $VOICE_ROLE   => 1,
    $DEFAULT_ROLE => 1,
    $GUEST_ROLE   => 1,
    $GAMING_ROLE  => 1,
    $REJECT_ROLE  => 1,
);

=head2 POOL

Constant used in the pool code

=cut

Readonly::Scalar our $POOL_USERNAMEHASH  => 'username_hash';
Readonly::Scalar our $POOL_RANDOM  => 'random';
Readonly::Scalar our $POOL_ROUND_ROBBIN => 'round_robbin';

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
