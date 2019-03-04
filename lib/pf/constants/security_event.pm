package pf::constants::security_event;

=head1 NAME

pf::constants::security_event - constants for security_event

=cut

=head1 DESCRIPTION

pf::constants::security_event

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;
use pf::constants;
use pf::constants::role qw($ISOLATION_ROLE $MAC_DETECTION_ROLE $VOICE_ROLE $INLINE_ROLE);

our @EXPORT_OK = qw($MAX_SECURITY_EVENT_ID $LOST_OR_STOLEN %NON_WHITELISTABLE_ROLES);

Readonly our $MAX_SECURITY_EVENT_ID => 2000000000;

Readonly our $LOST_OR_STOLEN => '1300005';

Readonly our %NON_WHITELISTABLE_ROLES => (
    $ISOLATION_ROLE     => $TRUE,
    $MAC_DETECTION_ROLE => $TRUE,
    $VOICE_ROLE         => $TRUE,
    $INLINE_ROLE        => $TRUE,
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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


