package pf::vlan::custom_example;

=head1 NAME

pf::vlan::custom

=head1 SYNOPSIS

This is a sample custom pf::vlan::custom module. It performs a database 
lookup on the requests coming from a Cisco WLC to pre-prend a building Id
to the returned VLAN. The query on the database is made using the 
Called-Station-Id to discriminate based on the AP.

This module extends pf::vlan

=head1 INSTALLATION

This module requires the presence of a special table in the database: 

    mysql> explain aps;
    +-----------------+-------------+------+-----+---------+-------+
    | Field           | Type        | Null | Key | Default | Extra |
    +-----------------+-------------+------+-----+---------+-------+
    | mac             | varchar(17) | NO   | PRI | NULL    |       |
    | building_id     | int(11)     | NO   |     | NULL    |       |
    | building_name   | text        | NO   |     | NULL    |       |
    +-----------------+-------------+------+-----+---------+-------+

Also, the Called-Sation-Id parameter must be added in pf::radius' 
fetchVlanForNode. Preferably do this in L<pf::radius::custom>.

    $radius_request->{'Called-Station-Id'}

Rename to pf/vlan/custom.pm and change package declaration to:

    package pf::vlan::custom;

=cut

use strict;
use warnings;

use Exporter qw( import );
use Log::Log4perl;

use constant CUSTOM => 'vlan::custom';

BEGIN {
    # use base must be performed before @EXPORT assignment otherwise we are not a subclass
    use base ('pf::vlan');
    our @EXPORT = qw(
        $custom_db_prepared
        custom_db_prepare
    );
}

use pf::config;
use pf::node qw(node_attributes node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);

our $VERSION = 1.01;

use pf::db;
# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $custom_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required 
our $custom_statements = {};

=head1 SUBROUTINES

=over

=item custom_db_prepare

Prepares the database statements.

=cut
sub custom_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $custom_statements->{'buildingnum_per_called_station_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT building_id
        FROM aps
        WHERE mac = ?
    SQL

    $custom_db_prepared = 1;

    return $TRUE;
}

=item buildingnum_per_called_station_id

Returns the building id matching the provided Called-Station-Id.

=cut
#   
# CUSTOM: here we fetch the building id for a given called station id
# Useful for per building per category VLAN assignments
#   
sub buildingnum_per_called_station_id {
    my ($called_station_id) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # extract MAC out of Called-Station-Id
    my $mac;
    if ($called_station_id =~ /^
        # below is MAC Address with supported separators: :, - or nothing
        ([a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2})
        :?                                                                                 # optional : delimiter
        (?:.*)?                                                                            # optional SSID
    $/ix) {
        $mac = clean_mac($1);
    } else {
        $logger->warn("Unable to extract MAC out of Called-Station-Id: $called_station_id");
        return;
    }

    my $query = db_query_execute(CUSTOM, $custom_statements, 'buildingnum_per_called_station_sql', $mac)
        || return;

    my ($val) = $query->fetchrow_array();
    $query->finish(); 
    return ($val);
}

=back

=head1 METHODS

=over

=item fetchVlanForNode

Answers the question: What VLAN should a given node be put into?

Overrides pf::vlan's fetchVlanForNode

CUSTOM: pass the Called-Station-Id to violation, registration and normal VLAN resolvers.

=cut
sub fetchVlanForNode {
    my ( $this, $mac, $switch, $ifIndex, $connection_type, $user_name, $ssid, $called_station_id ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');

    # violation handling
    my $violation = $this->getViolationVlan(
        $switch, $ifIndex, $mac, $connection_type, $user_name, $ssid, $called_station_id
    );
    if (defined($violation) && $violation != 0) {
        return $violation;
    } elsif (!defined($violation)) {
        $logger->warn("There was a problem identifying vlan for violation. Will act as if there was no violation.");
    }

    # there were no violation, now onto registration handling
    my $node_info = node_attributes($mac);
    my $registration = $this->getRegistrationVlan(
        $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $called_station_id
    );
    if (defined($registration) && $registration != 0) {
        return $registration;
    }

    # no violation, not unregistered, we are now handling a normal vlan
    my $vlan = $this->getNormalVlan(
        $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $called_station_id
    );
    if (!defined($vlan)) {
        $logger->warn("Resolved VLAN for node is not properly defined: Replacing with macDetectionVlan");
        $vlan = $switch->getVlanByName('macDetection');
    }
    $logger->info("MAC: $mac, PID: " .$node_info->{pid}. ", Status: " .$node_info->{status}. ". Returned VLAN: $vlan");
    return $vlan;
}


=item getViolationVlan

Returns the violation vlan for a node (if any)

Overrides pf::vlan::getViolationVlan

CUSTOM: handling called_station_id

Return values:
    
=over 6 
        
=item * -1 means kick-out the node (not always supported)
    
=item * 0 means no violation for this node
    
=item * undef means there was an error
    
=item * anything else is either a VLAN name string or a VLAN number
    
=back

=cut
sub getViolationVlan {
    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$conn_type is set to the connnection type expressed as the constant in pf::config 
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $connection_type, $user_name, $ssid, $called_station_id) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count == 0) {
        return 0;
    }

    $logger->debug("$mac has $open_violation_count open violations(s) with action=trap; ".
                   "it might belong into another VLAN (isolation or other).");
    
    # By default we assume that we put the user in isolationVlan unless proven otherwise
    my $vlan = "isolationVlan";

    # fetch top violation
    $logger->trace("What is the highest priority violation for this host?");
    my $top_violation = violation_view_top($mac);
    # fetching top violation failed
    if (!$top_violation || !defined($top_violation->{'vid'})) {
    
        $logger->warn("Could not find highest priority open violation for $mac. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return $switch->getVlanByName($vlan);
    }   
        
    # get violation id
    my $vid=$top_violation->{'vid'};
    
    # find violation class based on violation id
    require pf::class;
    my $class=pf::class::class_view($vid);
    # finding violation class based on violation id failed
    if (!$class || !defined($class->{'vlan'})) {

        $logger->warn("Could not find class entry for violation $vid. ".
                      "Setting target vlan to switches.conf's isolationVlan");
        return $switch->getVlanByName($vlan);
    }

    # override violation destination vlan
    $vlan = $class->{'vlan'};

    # example of a specific violation that packetfence should block instead of isolate
    # ex: block iPods / iPhones because they tend to overload controllers, radius and captive portal in isolation vlan
    # if ($vid == '1100004') { return -1; }

    # CUSTOM: returning per building VLAN id if switch type is Cisco::WLC
    my $vlan_number;
    if (defined($called_station_id) && ref($switch) eq 'pf::SNMP::Cisco::WLC_4400') {
        $vlan_number = buildingnum_per_called_station_id($called_station_id) . $switch->getVlanByName($vlan);
    }
    # Asking the switch to give us its configured vlan number for the vlan returned for the violation
    else {
        $vlan_number = $switch->getVlanByName($vlan);
    }
    if (defined($vlan_number)) {
        $logger->info("highest priority violation for $mac is $vid. Target VLAN for violation: $vlan ($vlan_number)");
    }
    return $vlan_number;
}

=item getRegistrationVlan

Returns the registration vlan for a node if registration is enabled and node is unregistered or pending.

Overrides pf::vlan's getRegistrationVlan

CUSTOM: handling called_station_id

Return values:

=over 6

=item * 0 means node is already registered

=item * undef means there was an error

=item * anything else is either a VLAN name string or a VLAN number
    
=back

=cut
sub getRegistrationVlan {
    #$switch is the switch object (pf::SNMP)
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
    #$conn_type is set to the connnection type expressed as the constant in pf::config 
    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $called_station_id) = @_;
    my $logger = Log::Log4perl->get_logger();

    # trapping on registration is enabled
    if (!isenabled($Config{'trapping'}{'registration'})) {
        $logger->debug("Registration trapping disabled: skipping node is registered test");
        return 0;
    }

    # CUSTOM: pre-compute registrationVlan based on being on a WLC or not
    my $vlan_number;
    if (defined($called_station_id) && ref($switch) eq 'pf::SNMP::Cisco::WLC_4400') {
        $vlan_number = 
            buildingnum_per_called_station_id($called_station_id) . $switch->getVlanByName('registration');
    }
    # Asking the switch to give us its configured vlan number for the vlan returned for the violation
    else {
        $vlan_number = $switch->getVlanByName('registration');
    }

    if (!defined($node_info)) {
        $logger->info("MAC: $mac doesn't have a node entry; belongs into registration VLAN");
        # CUSTOM: replaced $switch->getVlanByName('registration') with pre-computed VLAN above
        return $vlan_number;
    }

    my $n_status = $node_info->{'status'};
    if ($n_status eq $pf::node::STATUS_UNREGISTERED || $n_status eq $pf::node::STATUS_PENDING) {
        $logger->info("MAC: $mac is of status $n_status; belongs into registration VLAN");
        # CUSTOM: replaced $switch->getVlanByName('registration') with pre-computed VLAN above
        return $vlan_number;
    }
    return 0;
}

=item getNormalVlan

Sample getNormalVlan, see pf::vlan for getNormalVlan interface description

=cut

sub getNormalVlan {

    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $called_station_id) = @_;
    my $logger = Log::Log4perl->get_logger();

    # CUSTOM: fetching per building VLAN id if switch type is Cisco::WLC
    # by default no buliding id vlan prefix
    my $vlan_id_prefix = '';
    if (defined($called_station_id) && ref($switch) eq 'pf::SNMP::Cisco::WLC_4400') {
        $vlan_id_prefix = buildingnum_per_called_station_id($called_station_id);
    }

    # CUSTOM example: admin category
    # return customVlan to nodes based on category
    if (defined($node_info->{'category'}) && lc($node_info->{'category'}) eq "student") {
        return $vlan_id_prefix . $switch->getVlanByName('customVlan2');
    }
    elsif (defined($node_info->{'category'}) && lc($node_info->{'category'}) eq "staff")
    {
        return $vlan_id_prefix . $switch->getVlanByName('customVlan1');
    }
    elsif (defined($node_info->{'category'}) && lc($node_info->{'category'}) eq "guest")
    {
        return $vlan_id_prefix . $switch->getVlanByName('customVlan2');
    }

    $logger->warn("User was not assigned a catagory...Rejecting");
    return -1;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
