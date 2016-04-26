package pf::option82;

=head1 NAME

pf::option82 - module for option82 management.

=cut

=head1 DESCRIPTION

pf::option82 contains task to be able to use the dhcp option 82.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use pf::log;
use pf::CHI;
use pf::SwitchFactory;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        search_switch
    );
}


=head2 search_switch

Return the ip address of the switch that match the mac address on option 82 in dhcp packet

=cut

sub search_switch {
    my ($class, $mac) = @_;
    my $logger = pf::log::get_logger();
    my $cache = pf::CHI->new( namespace => 'switch' );
    foreach my $switch_id ( grep { $_ ne 'default' } keys %pf::SwitchFactory::SwitchConfig ) {
        my $switch = pf::SwitchFactory->instantiate($switch_id);
        my $switch_mac = $switch->getRelayAgentInfoOptRemoteIdSub();
        if ($switch_mac eq $mac) {
            $cache->set($mac, $switch_id);
            last;
        }
    }
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
