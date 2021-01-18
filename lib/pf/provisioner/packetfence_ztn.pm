package pf::provisioner::packetfence_ztn;

=head1 NAME

pf::provisioner::packetfence_ztn -

=head1 DESCRIPTION

pf::provisioner::packetfence_ztn

=cut

use strict;
use warnings;

use Moo;
extends 'pf::provisioner';
use pf::constants;

=head1 Atrributes

=head2 windows_agent_download_uri

URI to download the windows agent

=cut

has windows_agent_download_uri => (is => 'rw', default => "/content/packetfence-ztn-windows-x86-64.exe");

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has mac_osx_agent_download_uri => (is => 'rw', default => "/content/packetfence-ztn-macosx-x86-64.pkg");

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has linux_agent_download_uri => (is => 'rw', default => "/content/packetfence-ztn-linux-x86-64");

sub authorize {
    return $FALSE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
