package pfappserver::Form::Config::NetworkBehaviorPolicy;

=head1 NAME

pfappserver::Form::Config::NetworkBehaviorPolicy - Web form for the Network Behavior Policy portal 

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Policy ID',
   required => 1,
   messages => { required => 'Please specify a name of the Network Behavior Policy entry.' },
   apply => [ pfappserver::Base::Form::id_validator('policy ID') ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   }
  );

has_field 'description' =>
  (
   type => 'Text',
   messages => { required => 'Please specify the description of the Network Behavior Policy Portal entry.' },
  );

has_field 'devices_included' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'Devices Included',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a device'},
   tags => { after_element => \&help,
             help => 'The list of Fingerbank devices that will be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices. Leaving this empty will have all devices impacted by this policy.' },
   fingerbank_model => "fingerbank::Model::Device",
  );

has_field 'devices_excluded' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'Devices Excluded',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a device'},
   tags => { after_element => \&help,
             help => 'The list of Fingerbank devices that should not be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices.' },
   fingerbank_model => "fingerbank::Model::Device",
  );

has_field 'watch_blacklisted_ips' => (
   type            => 'Toggle',
   label           => 'Watch Blacklisted IPs',
   checkbox_value  => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
   tags => { after_element => \&help,
             help => 'Whether or not the policy should check if the endpoints are communicating with blacklisted IP addresses.' },
);

has_field 'whitelisted_ips' =>
  (
   type => 'Text',
   label => 'Whitelisted IPs',
   tags => { after_element => \&help,
             help => 'Which IPs (can be CIDR) to ignore when checking against the blacklisted IPs list' },
  );

has_field 'blacklisted_ip_hosts_window' => (
   label => 'Blacklisted IP Hosts Window',
   type => 'Duration',
   required => 1,
   tags => { after_element => \&help,
             help => 'The window to consider when counting the amount of blacklisted IPs the endpoint has communicated with.' },
);

has_field 'blacklisted_ip_hosts_threshold' =>
  (
   type => 'PosInteger',
   label => 'Blacklisted IPs Threshold',
   checkbox_value => 'enabled',
   tags => { after_element => \&help,
             help => 'If an endpoint talks with more than this amount of blacklisted IPs in the window defined above, then it triggers an event.' },
  );

has_field 'watched_device_attributes' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_device_attributes,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add an attribute'},
   tags => { after_element => \&help,
             help => 'Defines the attributes that should be analysed when checking against the pristine profile of the endpoint' },
  );

has_field 'device_attributes_diff_score' =>
  (
   type => 'PosInteger',
   label => 'Device Attributed Diff Score',
   checkbox_value => 'enabled',
   tags => { after_element => \&help,
             help => 'The score a device has to reach when its compared against the pristine profile of the endpoint. Anything lower than this will trigger an event.' },
  );

has_block definition =>
  (
   render_list => [ qw(id description devices_included devices_excluded watch_blacklisted_ips whitelisted_ips blacklisted_ip_hosts_window blacklisted_ip_hosts_threshold watched_device_attributes device_attributes_diff_score) ],
  );


sub options_device_attributes {
    my $self = shift;

    return (
        "dhcp_fingerprint" => "DHCP Fingerprint",
        "dhcp_vendor" => "DHCP vendor",
        "hostname" => "Hostname",
        "oui" => "OUI (Mac Vendor)",
        "destination_hosts" => "Destination Hosts",
        "mdns_services" => "mDNS services",
        "tcp_syn_signatures" => "TCP SYN signatures",
        "tcp_syn_ack_signatures" => "TCP SYN ACK signatures",
        "upnp_server_strings" => "UPnP Server Strings",
        "upnp_user_agents" => "UPnP User-Agents",
        "user_agents" => "HTTP User-Agents",
    );
}


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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
