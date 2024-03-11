package pf::pfcron::task::ubiquiti_ap_mac_to_ip;

=head1 NAME

pf::pfcron::task::ubiquiti_ap_mac_to_ip

=cut

=head1 DESCRIPTION

Cache the associated ip based on the mac address of the AP

=cut

use Moose;

use Net::IP;

use pf::Switch;
use pf::SwitchFactory;
use pf::util qw(isenabled);

use pf::log;
use List::MoreUtils qw(uniq);

extends qw(pf::pfcron::task);


=head2 run

Run the task

=cut

sub run {
    my ($self) = @_;

    my @switches = ();

    foreach my $switch_id ( grep { $pf::SwitchFactory::SwitchConfig{$_}{type} eq 'Ubiquiti::Unifi' } keys %pf::SwitchFactory::SwitchConfig ) {
        push @switches, $switch_id if defined($pf::SwitchFactory::SwitchConfig{$switch_id}{controllerIp});
    }
    populate_switch_cache(@switches);
}


=head2 populate_switch_cache

=cut

sub populate_switch_cache {
    my ( @switches ) = @_;

    my @switch = uniq(@switches);

    foreach my $switch_id (@switch) {

        my $switch = pf::SwitchFactory->instantiate($switch_id);

        unless ( ref($switch) ) {
            get_logger->error("Unable to instantiate switch object using switch_id '" . $switch_id . "'");
            return;
        }
        $switch->populateAccessPointMACIP();
    }
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
