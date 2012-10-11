package pf::inline;

=head1 NAME

pf::inline - Object oriented module for inline enforcement related operations

=head1 SYNOPSIS

The pf::inline module contains the functions necessary for the inline enforcement.
All the behavior contained here can be overridden in lib/pf/inline/custom.pm.

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::node qw(node_attributes);
use pf::violation qw(violation_count_trap);
use Try::Tiny;

our $VERSION = 1.01;

=head1 SUBROUTINES

=over

=item new

Constructor.
Usually you don't want to call this constructor but use the pf::inline::custom subclass instead.

=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::inline");
    $logger->debug("instantiating new pf::inline object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    $this->{_technique} = get_technique();
    return $this;
}

=item get_technique

Instantiate the correct iptables modification method between iptables and ipset

=cut
sub get_technique {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $type;
    if ($IPSET_VERSION > 0) {
        $type = "pf::ipset";
    } else {
        $type = "pf::iptables";
    }

    $logger->info("Instantiate a new iptables modification method. ". $type);
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
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # What is the MAC's current state?
    my $current_mark = $this->{_technique}->get_mangle_mark_for_mac($mac);
    my $should_be_mark = $this->fetchMarkForNode($mac);

    if ($current_mark == $should_be_mark) {
        $logger->debug("MAC: $mac is already properly enforced in firewall, no change required");
        return $TRUE;
    }

    $logger->info("MAC: $mac stated changed, adapting firewall rules for proper enforcement");
    return $this->{_technique}->update_mark($mac, $current_mark, $should_be_mark);
}

=item isInlineEnforcementRequired

Returns a true value if a firewall change is required. False otherwise.

=cut
sub isInlineEnforcementRequired {
    my ($this, $mac) = @_;

    # What is the MAC's current state?
    my $current_mark = $this->{_technique}->get_mangle_mark_for_mac($mac);
    my $should_be_mark = $this->fetchMarkForNode($mac);
    if ($current_mark == $should_be_mark) {
        return $FALSE;
    }
    return $TRUE;
}

=item fetchMarkForNode

=cut
sub fetchMarkForNode {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # Violation first
    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count != 0) {
        $logger->info(
            "MAC: $mac has $open_violation_count open violations(s) with action=trap; it needs to firewalled"
        );
        return $IPTABLES_MARK_ISOLATION;
    }

    # looking at the node's registration status
    # at this point we don't care whether trapping.registration is enabled or not
    # we can do this because actual enforcement is done on startup by adding proper DNAT and forward ACCEPT
    my $node_info = node_attributes($mac);
    if (!defined($node_info)) {
        $logger->debug("MAC: $mac doesn't have a node entry; it needs to be firewalled");
        return $IPTABLES_MARK_UNREG;
    }

    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        $logger->debug("MAC: $mac is of status $n_status; needs to be firewalled");
        return $IPTABLES_MARK_UNREG;
    }

    # At this point, we are registered and we don't have a violation: allow through
    $logger->debug("MAC: $mac should be allowed through firewall");
    return $IPTABLES_MARK_REG;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
