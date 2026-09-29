package pf::pfcron::task::switch_cache_ifindex;

=head1 NAME

pf::pfcron::task::switch_cache_ifindex

=cut

=head1 DESCRIPTION

Keep the cache of the SNMP tables switch modules read to translate the
NAS-Port-Id of a RADIUS request into an ifIndex (the ifDescr walk of the Cisco,
Arista, Aruba and 3Com modules) up to date, so that a RADIUS request never
waits for the walk. On SNMPv1, the walk takes one round trip per interface.

The cache entries live 48h (chi.conf, namespace switch_distributed), the task
runs every 12h by default.

=cut

use strict;
use warnings;
use Moose;
use Net::IP;
use pf::SwitchFactory;
use pf::util qw(isenabled);
use pf::log;
extends qw(pf::pfcron::task);

has 'process_switchranges' => ( is => 'rw', default => 'disabled' );

=head2 run

Run the task

=cut

sub run {
    my ($self) = @_;
    my ($refreshed, $failed) = (0, 0);
    foreach my $switch_id ( sort keys %pf::SwitchFactory::SwitchConfig ) {
        next if ( ($switch_id !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) || ($switch_id eq "127.0.0.1") );
        my @ids = ($switch_id);
        if ( $switch_id =~ /\// ) {
            next unless isenabled( $self->process_switchranges );
            @ids = ();
            my $range = Net::IP->new($switch_id);
            next unless $range;
            do { push @ids, $range->ip() } while (++$range);
        }
        foreach my $id (@ids) {
            my $result = refresh_switch($id);
            next unless defined $result;
            $result ? $refreshed++ : $failed++;
        }
    }
    get_logger->info("Refreshed the ifIndex cache of $refreshed switches ($failed failed)");
    return;
}

=head2 refresh_switch

Refresh the ifIndex cache of one switch. Returns undef when the switch module
has nothing to cache, true or false for the outcome of the refresh.

=cut

sub refresh_switch {
    my ($switch_id) = @_;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ( ref($switch) ) {
        get_logger->error("Unable to instantiate switch object using switch_id '$switch_id'");
        return 0;
    }
    return undef if $switch->can('refreshIfIndexCache') == pf::Switch->can('refreshIfIndexCache');
    my $ok = $switch->refreshIfIndexCache();
    get_logger->debug("ifIndex cache of switch '$switch_id' " . ($ok ? "refreshed" : "not refreshed (SNMP unreachable?)"));
    return $ok ? 1 : 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
