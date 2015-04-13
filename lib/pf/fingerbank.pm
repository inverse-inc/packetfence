package pf::fingerbank;

=head1 NAME

pf::fingerbank

=head1 DESCRIPTION

Methods to interact with Fingerbank librairy

=cut

use strict;
use warnings;

use Switch;

use fingerbank::Model::DHCP_Fingerprint;
use fingerbank::Model::DHCP_Vendor;
use fingerbank::Model::MAC_Vendor;
use fingerbank::Model::User_Agent;
use fingerbank::Query;

use pf::api::jsonrpcclient;
use pf::error qw(is_error);
use pf::CHI;
use pf::log;
use pf::node qw(node_modify);

use constant FINGERBANK_CACHE_EXPIRE => 300;    # Expires cache entry after 300s (5 minutes)

our @fingerbank_based_violation_triggers = ('Device', 'DHCP_Fingerprint', 'DHCP_Vendor', 'MAC_Vendor', 'User_Agent');

=head1 METHODS

=head2 process

=cut

sub process {
    my ( $query_args ) = @_;
    my $logger = pf::log::get_logger;

    my $mac = $query_args->{'mac'};

    # Querying for a resultset
    my $query_result = _query($query_args);

    if ( ref($query_result) ne "HASH" ) {
        $logger->warn("Unable to perform a Fingerbank lookup for device with MAC address '$mac'");
        return "";
    }

    # Processing the device class based on it's parents
    my ( $class, $parents ) = _parse_parents($query_result);

    # Updating the node device type based on the result
    node_modify( $mac, ( 
        'device_type'   => $query_result->{'device'}{'name'},
        'device_class'  => $class,
    ) );

    _trigger_violations($query_args, $query_result, $parents);

    return $query_result->{'device'}{'name'};
}

=head2 _query

=cut

sub _query {
    my ( $args ) = @_;
    my $logger = pf::log::get_logger;

    my $cache = pf::CHI->new( namespace => 'fingerbank' );

    # Doing a shallow copy or the args hashref to remove 'mac' from it.
    # We are using the args as the cache key and don't want to have 'mac' since it is too specific
    my $cached_args = { %$args };
    delete $cached_args->{'mac'};

    return $cache->compute($cached_args, {expires_in => FINGERBANK_CACHE_EXPIRE},
        sub {
            $logger->debug("Fingerbank result not in cache (either not present or expired). Querying Fingerbank for result");
            my $fingerbank = fingerbank::Query->new;
            return $fingerbank->match($args);
        }
    );
}

=head2 _trigger_violations

=cut

sub _trigger_violations {
    my ( $query_args, $query_result, $parents ) = @_;
    my $logger = pf::log::get_logger;

    my $mac = $query_args->{'mac'};

    my $apiclient = pf::api::jsonrpcclient->new;

    foreach my $trigger_type ( @fingerbank_based_violation_triggers ) {
        my $trigger_data;
        switch ( $trigger_type ) {
            case 'Device' {
                next if !$query_result->{'device'}{'id'};
                $trigger_data = $query_result->{'device'}{'id'};
            }

            case 'MAC_Vendor' {
                next if !$mac;
                my $mac_oui = $mac;
                $mac_oui =~ s/[:|\s|-]//g;          # Removing separators
                $mac_oui = lc($mac_oui);            # Lowercasing
                $mac_oui = substr($mac_oui, 0, 6);  # Only keep first 6 characters (OUI)
                my $trigger_query;
                $trigger_query->{'mac'} = $mac_oui;
                my ( $status, $result ) = "fingerbank::Model::$trigger_type"->find([$trigger_query, { columns => ['id'] }]);
                next if is_error($status);
                $trigger_data = $result->id;
            }

            else {
                next if !$query_args->{lc($trigger_type)};
                my $trigger_query;
                $trigger_query->{'value'} = $query_args->{lc($trigger_type)};
                my ( $status, $result ) = "fingerbank::Model::$trigger_type"->find([$trigger_query, { columns => ['id'] }]);
                next if is_error($status);
                $trigger_data = $result->id;
            }
        }

        next if !$trigger_data;

        my %violation_data = (
            'mac'   => $mac,
            'tid'   => $trigger_data,
            'type'  => $trigger_type,
        );

        $logger->debug("Trying to trigger a violation type '$trigger_type' for MAC '$mac' with data '$trigger_data'");
        $apiclient->notify('trigger_violation', %violation_data);
    }

    # Parent(s) based violations
    if ( @$parents ) {
        $logger->debug("Device of ID '" . $query_result->{'device'}{'id'} . "' with MAC address '$mac' does have parent(s). Trying to trigger violation type 'Device' for each of them");
        foreach my $parent ( @$parents ) {
            my %violation_data = (
                'mac'   => $mac,
                'tid'   => $parent,
                'type'  => 'Device',
            );

            $logger->debug("Trying to trigger a violation type 'Device' based on parent(s) for MAC address '$mac' with data '$parent'");
            $apiclient->notify('trigger_violation', %violation_data);
        }
    }
}

=head2 _parse_parents

Parsing the parents into an array of IDs to be able to trigger violations based on them.

Also, looking at the top-level parent to determine the device class

=cut

sub _parse_parents {
    my ( $args ) = @_;
    my $logger = pf::log::get_logger;

    my $class;
    my @parents = ();

    # It is possible that a device doesn't have any parent. We need to handle that case first
    if ( !@{ $args->{'device'}{'parents'} } ) {
        $class = $args->{'device'}{'name'};
        $logger->debug("Device doesn't have any parent. We use the device name '$class' as class.");
        return ( $class, \@parents );
    }

    foreach my $parent ( @{ $args->{'device'}{'parents'} } ) {
        push @parents, $parent->{'id'};
        next if $parent->{'parent_id'};
        $class = $parent->{'name'};
        $logger->debug("Device does have parent(s). Returning top-level parent name '$class' as class");
    }

    return ( $class, \@parents );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
