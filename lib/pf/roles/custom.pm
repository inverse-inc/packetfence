package pf::roles::custom;

=head1 NAME

pf::roles::custom - OO module that performs the roles lookups for nodes

=head1 SYNOPSIS

The pf::roles::custom implements roles lookups for nodes that are custom to a particular setup. 

This module extends pf::roles

=head1 EXPERIMENTAL

This module is considered experimental. For example not a lot of information
is provided to make the role decisions. This is expected to change in the
future at the cost of API changes.

You have been warned!

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::node qw(node_attributes);
use pf::violation qw(violation_count_trap);

use base ('pf::roles');

our $VERSION = 0.90;

=head1 SUBROUTINES

=over

=cut


=item getRoleForNode

Returns the proper role for a given node.

=cut
sub getRoleForNode {
    my ($self, $mac, $switch) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));

    # Violation first
    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count != 0) {
        $logger->info("MAC: $mac has $open_violation_count open violations(s) with action=trap; no role returned");
        return;
    }

    # looking at the node's registration status
    my $node_attributes = node_attributes($mac);
    if (!defined($node_attributes)) {
        $logger->debug("MAC: $mac doesn't have a node entry; no role returned");
        return;
    }

    my $n_status = $node_attributes->{'status'};

    if ( $n_status eq $pf::node::STATUS_UNREGISTERED ) {
        return $switch->getRoleByName('registration');
    } elsif ( $n_status eq $pf::node::STATUS_REGISTERED ) {
        return $switch->getRoleByName('default');
    } else {
        return;
    }

#    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
#        $logger->debug("MAC: $mac is of status $n_status; no role returned");
#        return;
#    }

#    # At this point, we are registered, we don't have a violation: perform Role lookup
#    return $self->performRoleLookup($node_attributes, $switch);
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

