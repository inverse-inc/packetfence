package pf::Switch::Huawei::S5710;


=head1 NAME

pf::Switch::Huawei::S5710

=head1 SYNOPSIS

The pf::Switch::Huawei::S5710 module manages access to Huawei

=head1 STATUS

There is no way to determine the SNMP ifindex from the RADIUS request.

Bumping a port doesn't reevaluate the access.

=cut

use strict;
use warnings;

use pf::log;
use POSIX;
use Try::Tiny;

use base ('pf::Switch::Huawei');

use pf::constants;
sub description { 'Huawei S5710' }

=head1 SUBROUTINES

=cut

sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

=head2 getIfType

Returning ETHERNET type since there is no standard way to get the ifindex

=cut

sub getIfType{ return $SNMP::ETHERNET_CSMACD; }

=head2 handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

=cut

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = get_logger();

    $self->deauthenticateMacRadius($mac);
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
