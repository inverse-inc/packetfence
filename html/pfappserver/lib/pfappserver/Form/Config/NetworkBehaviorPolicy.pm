package pfappserver::Form::Config::NetworkBehaviorPolicy;

=head1 NAME

pfappserver::Form::Config::NetworkBehaviorPolicy - Web form for the Network Behavior Policy portal 

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Role::Form::RolesAttribute
);

## Definition
has_field 'id' =>
  (
   type => 'Text',
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

has_field 'status' => (
   type            => 'Toggle',
   checkbox_value  => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
   required => 1,
);

has_field 'devices_included' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a device'},
   fingerbank_model => "fingerbank::Model::Device",
   no_options => 1,
  );

has_field 'devices_excluded' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a device'},
   fingerbank_model => "fingerbank::Model::Device",
   no_options => 1,
  );

has_field 'watch_blacklisted_ips' => (
   type            => 'Toggle',
   checkbox_value  => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
   required => 1,
);

has_field 'whitelisted_ips' =>
  (
   type => 'Text',
  );

has_field 'blacklisted_ip_hosts_window' => (
   type => 'Duration',
   with_time_only => 1,
   default => {
    interval => 10,
    unit => 's',
   },
);

has_field 'blacklisted_ports' =>
  (
   type => 'Text',
  );

has_field 'blacklisted_ports_window' => (
   type => 'Duration',
   with_time_only => 1,
   default => {
    interval => 1,
    unit => 'm',
   },
);

has_field 'blacklisted_ip_hosts_threshold' =>
  (
   type => 'PosInteger',
   checkbox_value => 'enabled',
   default => 1,
   required => 1,
  );

has_field 'watched_device_attributes' =>
  (
   type => 'Select',
   multiple => 1,
   options_method => \&options_device_attributes,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add an attribute'},
  );

has_field 'device_attributes_diff_score' =>
  (
   type => 'PosInteger',
   checkbox_value => 'enabled',
   required => 1,
   default => 0,
  );

has_field 'device_attributes_diff_threshold_overrides' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
     tags => { 
       when_empty => 'If none are specified, the default ones of the module will be used.' 
     },
  );

has_field 'device_attributes_diff_threshold_overrides.contains' =>
  (
    type => '+NetworkBehaviorPolicyAttributeWeight',
    widget_wrapper => 'DynamicTableRow',
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
