package pf::pfmon::task::switch_cache_lldpLocalPort_description;

=head1 NAME

pf::pfmon::task::switch_cache_lldpLocalPort_description

=cut

=head1 DESCRIPTION

Cache switch costly SNMP call to get table of LLDP local port descriptions

=cut

use Moose;

use Net::IP;

use pf::Switch;
use pf::SwitchFactory;
use pf::util qw(isenabled);

use pf::log;

extends qw(pf::pfmon::task);

has 'process_switchranges'  => ( is => 'rw', default => 'disabled' );


=head2 run

Run the task

=cut

sub run {
    my ($self) = @_;

    my @lldp_detection_switches = ();
    foreach my $switch_entry ( keys \%pf::SwitchFactory::SwitchConfig ) {
        next if ( ($switch_entry !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) || ($switch_entry eq "127.0.0.1") );
        push @lldp_detection_switches, $switch_entry if isenabled($pf::SwitchFactory::SwitchConfig{$switch_entry}{VoIPLLDPDetect});
    }

    foreach my $switch ( @lldp_detection_switches ) {
        # Switch range
        if ( $switch =~ /\// && isenabled($self->process_switchranges) ) {
            get_logger->info("Processing switch range '$switch'");
            my $ip = new Net::IP($switch);
            do {
                populate_switch_cache($ip->ip());
            } while (++$ip);
        } else {
            populate_switch_cache($switch);
        }
    }
}


=head2 populate_switch_cache

=cut

sub populate_switch_cache {
    my ( $switch_id ) = @_;
    get_logger->info("Populating LLDP desc switch cache for switch '$switch_id'");

    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ( ref($switch) ) {
        get_logger->error("Unable to instantiate switch object using switch_id '" . $switch_id . "'");
    }

    $switch->getLldpLocPortDesc();
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
