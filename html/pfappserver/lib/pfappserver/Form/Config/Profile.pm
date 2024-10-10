package pfappserver::Form::Config::Profile;

=head1 NAME

pfappserver::Form::Config::Profile

=head1 DESCRIPTION

Connection profile.

=cut

use pf::authentication;

use HTML::FormHandler::Moose;
use pfappserver::Form::Config::FilterEngines;
use pfappserver::Form::Field::ProfileFilter;
extends 'pfappserver::Base::Form';
with 'pfappserver::Form::Config::ProfileCommon';

use pf::config qw(%Config);
use pf::condition_parser;
use List::MoreUtils qw(uniq);

=head1 FIELDS

=head2 filter

The filter container field

=cut

has_field 'filter' =>
  (
   type => 'DynamicTable',
   label => 'Filters',
   'do_label' => 0,
   'sortable' => 1,
  );

=head2 filter.conatains

The filter container field contents

=cut

has_field 'filter.contains' =>
  (
   type => '+ProfileFilter',
   widget_wrapper => 'DynamicTableRow',
  );

=head2 filter_match_style

The form field for filter_match_style
Field defining how the configured filters will be applied for matching

=cut

has_field 'filter_match_style' =>
(
    type => 'Select',
    default => 'any',
    options_method => \&options_filter_match_style,
    element_class => ['input-mini'],
);

=head2 status

The status of the profile if it is enabled or disabled

=cut

has_field 'status' =>
  (
   type => 'Toggle',
   label => 'Enable profile',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled'
  );

sub options_filter_match_style {
    return  map { { value => $_, label => $_ } } qw(all any);
}

has_field 'advanced_filter' =>
(
    type => 'FilterCondition',
);

=head1 METHODS

=head2 update_fields

Don't allow to edit the profile id when editing an existing profile.

=cut

sub update_fields {
    my $self = shift;
    my $init_object = $self->init_object;

    $self->field('id')->readonly(1) if (defined $init_object && defined $init_object->{id});

    # Call the theme implementation of the method
    $self->SUPER::update_fields();
}

=head2 validate

=cut

after validate => sub {
    my ($self) = @_;
    my $value = $self->value;
    my $advanced_filter = $value->{advanced_filter};
    my $condition_str = '';
    if (defined $advanced_filter) {
        $condition_str = pf::condition_parser::object_to_str($advanced_filter);
    }

    if (@{$value->{filter}} == 0 && (!defined $advanced_filter || $condition_str eq '')) {
        $self->field('filter')->add_error("A filter or an advanced filter must be specified");
        $self->field('advanced_filter')->add_error("A filter or an advanced filter must be specified");
    }

    if (defined $advanced_filter) {
        my ($conditions, $err) = pf::condition_parser::parse_condition_string($advanced_filter);
        if ($err) {
            $self->field('advanced_filter')->add_error($err->{message});
        }
    }
};

sub make_field_options {
    my ($self, $name) = @_;
    my %options = (
        label => $name,
        value => $name,
        $self->additional_field_options($name),
    );
    return \%options;
}

sub options_field {
    my ($self) = @_;
    return map { $self->make_field_options($_) } $self->options_field_names();
}

sub additional_field_options {
    my ($self, $name) = @_;
    my $options = $self->_additional_field_options;
    if (!exists $options->{$name}) {
        return;
    }

    my $more = $options->{$name};
    my $ref = ref $more;
    if ($ref eq 'HASH') {
        return %$more;
    } elsif ($ref eq 'CODE') {
        return $more->($self, $name);
    }

    return;
}

=head2 definition

The main definition block

=cut

has_block 'definition' =>
  (
    render_list => [qw(id description status root_module preregistration autoregister reuse_dot1x_credentials dot1x_recompute_role_from_portal mac_auth_recompute_role_from_portal dot1x_unset_on_unmatch dpsk unbound_dpsk default_psk_key unreg_on_acct_stop)],
  );

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    (
        qw(
          autoreg
          bandwidth_balance
          bypass_role
          bypass_role_id
          bypass_vlan
          category
          category_id
          computername
          connection_sub_type
          connection_type
          detect_date
          device_class
          device_manufacturer
          device_score
          device_type
          device_version
          dhcp6_enterprise
          dhcp6_fingerprint
          dhcp_fingerprint
          dhcp_vendor
          fqdn
          last_arp
          last_connection_sub_type
          last_connection_type
          last_dhcp
          last_dot1x_username
          last_ifDesc
          last_ip
          last_port
          last_role
          last_seen
          last_ssid
          last_start_time
          last_start_timestamp
          last_switch
          last_switch_mac
          last_vlan
          mac
          machine_account
          network
          node_role
          notes
          pid
          port
          realm
          regdate
          sessionid
          ssid
          status
          stripped_user_name
          switch
          switch_group
          switch_mac
          time
          time_balance
          unregdate
          uri
          user_agent
          vlan
          voip
        ),
        (
           map { "radius_request.$_" } (
               @{$Config{radius_configuration}{radius_attributes} // []}
           )
        )
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
