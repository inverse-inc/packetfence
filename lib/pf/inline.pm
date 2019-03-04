package pf::inline;

=head1 NAME

pf::inline - Object oriented module for inline enforcement related operations

=head1 SYNOPSIS

The pf::inline module contains the functions necessary for the inline enforcement.
All the behavior contained here can be overridden in lib/pf/inline/custom.pm.

=cut

use strict;
use warnings;

use pf::log;

use pf::constants;
use pf::constants::role;
use pf::config qw(
    $IPTABLES_MARK_UNREG
    $IPTABLES_MARK_REG
    %ConfigNetworks
    $IPTABLES_MARK_ISOLATION
);
use pf::node qw(node_attributes);
use pf::security_event qw(security_event_count_reevaluate_access);
use Try::Tiny;
use NetAddr::IP;
use pf::util;

our $VERSION = 1.01;

=head1 SUBROUTINES

=over

=item new

Constructor.
Usually you don't want to call this constructor but use the pf::inline::custom subclass instead.

=cut

sub new {
    my $logger = get_logger();
    $logger->debug("instantiating new pf::inline object");
    my ( $class, %argv ) = @_;
    my $self = bless {}, $class;
    $self->{_technique} = get_technique();
    return $self;
}

=item get_technique

Instantiate the correct iptables modification method between iptables and ipset

=cut

sub get_technique {
    my $logger = get_logger();
    my $type;
    $type = "pf::ipset";

    $logger->debug("Instantiate a new iptables modification method. ". $type);
    try {
        # try to import module and re-throw the error to catch if there's one
        eval "use $type";
        die($@) if ($@);

    } catch {
        chomp($_);
        $logger->error("Initialization of iptables modification method failed: $_");
    };

    return $type->new();
}


=item performInlineEnforcement

=cut

sub performInlineEnforcement {
    my ($self, $mac) = @_;
    my $logger = get_logger(ref($self));

    # What is the MAC's current state?
    my $current_mark = $self->{_technique}->get_mangle_mark_for_mac($mac);
    my $should_be_mark = $self->fetchMarkForNode($mac);

    if ($current_mark == $should_be_mark) {
        $logger->debug("is already properly enforced in firewall, no change required");
        return $TRUE;
    }

    $logger->info("stated changed, adapting firewall rules for proper enforcement");
    return $self->{_technique}->update_mark($mac, $current_mark, $should_be_mark);
}

=item isInlineEnforcementRequired

Returns a true value if a firewall change is required. False otherwise.

=cut

sub isInlineEnforcementRequired {
    my ($self, $mac) = @_;

    # What is the MAC's current state?
    my $current_mark = $self->{_technique}->get_mangle_mark_for_mac($mac);
    my $should_be_mark = $self->fetchMarkForNode($mac);
    if ($current_mark == $should_be_mark) {
        return $FALSE;
    }
    return $TRUE;
}

=item fetchMarkForNode

=cut

sub fetchMarkForNode {
    my ($self, $mac) = @_;
    my $logger = get_logger(ref($self));

    # SecurityEvent first
    my $open_security_event_count = pf::security_event::security_event_count_reevaluate_access($mac);
    if ($open_security_event_count != 0) {
        $logger->info(
            "has $open_security_event_count open security_events(s) with action=trap; it needs to firewalled"
        );
        return $IPTABLES_MARK_ISOLATION;
    }

    # looking at the node's registration status
    # we can do this because actual enforcement is done on startup by adding proper DNAT and forward ACCEPT
    my $node_info = node_attributes($mac);
    if (!defined($node_info)) {
        $logger->debug("doesn't have a node entry; it needs to be firewalled");
        return $IPTABLES_MARK_UNREG;
    }

    # Check node status
    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        $logger->debug("is of status $n_status; needs to be firewalled");
        return $IPTABLES_MARK_UNREG;
    }

    # Check node role
    my $n_role = $node_info->{'category'};
    if ( $n_role eq $pf::constants::role::REJECT_ROLE ) {
        $logger->debug("is of role '$pf::constants::role::REJECT_ROLE'; needs to be firewalled");
        return $IPTABLES_MARK_UNREG;
    }

    # At this point, we are registered and we don't have a security_event: allow through
    $logger->debug("should be allowed through firewall");
    return $IPTABLES_MARK_REG;
}

=item isInlineIP

Returns a true if the ip address is in a inline network.

=cut


sub isInlineIP {
    my ($self, $ip) =@_;
    my $logger = get_logger(ref($self));

    foreach my $network ( keys %ConfigNetworks ) {
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $ip = NetAddr::IP::Lite->new(clean_ip($ip));
        if ($net_addr->contains($ip)) {
            return $TRUE;
        }
    }
    return $FALSE;
}

=back

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
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
