package pf::fingerbank;

=head1 NAME

pf::fingerbank

=head1 DESCRIPTION

Methods to interact with Fingerbank librairy

=cut

use strict;
use warnings;

use JSON::MaybeXS;

use fingerbank::Model::DHCP_Fingerprint;
use fingerbank::Model::DHCP_Vendor;
use fingerbank::Model::MAC_Vendor;
use fingerbank::Model::User_Agent;
use fingerbank::Query;
use fingerbank::FilePath;
use fingerbank::Model::Endpoint;
use pf::cluster;
use pf::constants;

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

    if($query_args->{mac}){
        my $node_info = pf::node::node_view($query_args->{mac});
        if($node_info){
            my @base_params = qw(dhcp_fingerprint dhcp_vendor dhcp6_fingerprint dhcp6_enterprise);
            foreach my $param (@base_params){
                $query_args->{$param} = $query_args->{$param} // $node_info->{$param};
            }
            # ip is a special case as it's not in the node_info
            $query_args->{ip} = $query_args->{ip} // pf::iplog::mac2ip($query_args->{mac}) || undef;
        }
    }

    my $mac = $query_args->{'mac'};

    # Querying for a resultset
    my $query_result = _query($query_args);

    if ( is_error($query_result) ) {
        $logger->warn("Unable to perform a Fingerbank lookup for device with MAC address '$mac'");
        return "unknown";
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

    my %violation_data = (
        'mac'   => $mac,
        'tid'   => 'new_dhcp_info',
        'type'  => 'internal',
    );

    $apiclient->notify('trigger_violation', %violation_data);

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
    if ( !defined($args->{'device'}{'parents'}) || !@{ $args->{'device'}{'parents'} } ) {
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

=head2 is_a

Testing which "kind" of device a specific type is.

Currently handled "kind" of device (based on Fingerbank device classes):
- Windows
- Macintosh
- Generic Android
- Apple iPod, iPhone or iPad

=cut

sub is_a {
    my ( $device_type ) = @_;
    my $logger = pf::log::get_logger;

    if ( !defined($device_type) || $device_type eq '' ) {
        $logger->debug("Undefined / invalid device type passed");
        return "unknown";
    }

    $logger->debug("Trying to determine the kind of device for '$device_type' device type");

    my $endpoint = fingerbank::Model::Endpoint->new(name => $device_type, version => undef, score => undef);

    return "Windows" if ( $endpoint->isWindows($device_type) );
    # Macintosh / Mac OS
    return "Macintosh" if ( $endpoint->isMacOS($device_type) );
    # Android
    return "Generic Android" if ( $endpoint->isAndroid($device_type) );
    # Apple IOS
    return "Apple iPod, iPhone or iPad" if ( $endpoint->isIOS($device_type) );

    # Unknown (we were not able to match)
    return "unknown";
}

sub sync_configuration {
    pf::cluster::sync_files([$fingerbank::FilePath::CONF_FILE]);
}

sub sync_local_db {
    pf::cluster::sync_files([$fingerbank::FilePath::LOCAL_DB_FILE]);
}

sub sync_upstream_db {
    pf::cluster::sync_files([$fingerbank::FilePath::UPSTREAM_DB_FILE], async => $TRUE);
}

=head2 mac_vendor_from_mac

=cut

sub mac_vendor_from_mac {
    my ($mac) = @_;
    my $mac_oui = $mac;
    $mac_oui =~ s/[:|\s|-]//g;          # Removing separators
    $mac_oui = lc($mac_oui);            # Lowercasing
    $mac_oui = substr($mac_oui, 0, 6);  # Only keep first 6 characters (OUI)
    my $trigger_query;
    $trigger_query->{'mac'} = $mac_oui;
    my ( $status, $result ) = "fingerbank::Model::MAC_Vendor"->find([$trigger_query, { columns => ['id'] }]);
    return undef if is_error($status);

    ( $status, $result ) = "fingerbank::Model::MAC_Vendor"->read($result->id);
    return $result;
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
