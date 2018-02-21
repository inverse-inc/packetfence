package pfappserver::Form::Config::ProfileCommon;

=head1 NAME

pfappserver::Form::Profile::Common add documentation

=cut

=head1 DESCRIPTION

pfappserver::Config::Form::ProfileCommon

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose::Role;
use List::MoreUtils qw(uniq);

use pf::authentication;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::BillingTiers;
use pf::ConfigStore::Scan;
use pf::ConfigStore::DeviceRegistration;
use pf::ConfigStore::PortalModule;
use pf::web::constants;
use pf::constants::Connection::Profile;
use pfappserver::Form::Field::Duration;
use pfappserver::Base::Form;
with 'pfappserver::Base::Form::Role::Help';

=head1 BLOCKS

=head2 definition

The main definition block

=cut

has_block 'definition' =>
  (
    render_list => [qw(id description root_module preregistration autoregister reuse_dot1x_credentials dot1x_recompute_role_from_portal)],
  );

=head2 captive_portal

The captival portal block

=cut

has_block 'captive_portal' =>
  (
    render_list => [qw(logo redirecturl always_use_redirecturl block_interval sms_pin_retry_limit sms_request_limit login_attempt_limit access_registration_when_registered)],
  );

=head1 Fields

=head2 id

Id of the profile

=cut

has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   apply => [ pfappserver::Base::Form::id_validator('profile name') ],
   tags => { after_element => \&help,
             help => 'A profile id can only contain alphanumeric characters, dashes, period and or underscores.' },
  );

=head2 description

Description of the profile

=cut

has_field 'description' =>
  (
   type => 'Text',
   label => 'Profile Description',
  );

=head2 logo

The logo field

=cut

has_field 'logo' =>
  (
   type => 'Text',
   label => 'Logo',
  );

=head2 root_module

The root module of the portal

=cut

has_field 'root_module' =>
  (
   type => 'Select',
   multiple => 0,
   required => 1,
   label => 'Root Portal Module',
   options_method => \&options_root_module,
   element_class => ['chzn-select'],
#   element_attr => {'data-placeholder' => 'Click to add a required field'},
   tags => { after_element => \&help,
             help => 'The Root Portal Module to use' },
  );

=head2 locale

Accepted languages for the profile

=cut

has_field 'locale' =>
(
    'type' => 'DynamicTable',
    'label' => 'Locales',
    'sortable' => 1,
    'do_label' => 0,
);

has_field 'locale.contains' =>
(
    type => 'Select',
    options_method => \&options_locale,
    widget_wrapper => 'DynamicTableRow',
);

=head2 redirecturl

Redirection URL

=cut

has_field 'redirecturl' =>
  (
   type => 'Text',
   label => 'Redirection URL',
   tags => { after_element => \&help,
             help => 'Default URL to redirect to on registration/mitigation release. This is only used if a per-violation redirect URL is not defined.' },
  );

=head2 always_use_redirecturl

Controls whether or not we always use the redirection URL

=cut

has_field 'always_use_redirecturl' =>
  (
   type => 'Toggle',
   label => 'Force redirection URL',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.' },
  );

=head2 preregistration

Controls whether or not this connection profile is used for preregistration

=cut

has_field 'preregistration' =>
  (
   type => 'Toggle',
   label => 'Activate preregistration',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have "Create local account" enabled.' },
  );


=head2 autoregister

Controls whether or not this connection profile will autoregister users

=cut

has_field 'autoregister' =>
  (
   type => 'Toggle',
   label => 'Automatically register devices',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.' },
  );

=head2 sources

Collection Authentication Sources for the profile

=cut

has_field 'sources' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

=head2 sources.contains

The definition for Authentication Sources field

=cut

has_field 'sources.contains' =>
  (
    type => 'Select',
    options_method => \&options_sources,
    widget_wrapper => 'DynamicTableRow',
  );


=head2 billing_tiers

Collection Billing tiers for the profile

=cut

has_field 'billing_tiers' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

=head2 billing_tiers.contains

The definition for Billing tiers field

=cut

has_field 'billing_tiers.contains' =>
  (
    type => 'Select',
    options_method => \&options_billing_tiers,
    widget_wrapper => 'DynamicTableRow',
);

=head2 provisioners

Collectiosn Authentication Sources for the profile

=cut

has_field 'provisioners' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

=head2 provisioners.contains

The definition for Authentication Sources field

=cut

has_field 'provisioners.contains' =>
  (
    type => 'Select',
    options_method => \&options_provisioners,
    widget_wrapper => 'DynamicTableRow',
  );

=head2 reuse_dot1x_credentials

=cut

has_field 'reuse_dot1x_credentials' =>
  (
    type => 'Checkbox',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    tags => {
        after_element   =>    \&help,
        help            => 'This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.'
    },
  );

=head2 dot1x_recompute_role_from_portal

=cut

has_field 'dot1x_recompute_role_from_portal' =>
  (
    type => 'Checkbox',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled',
    tags => { after_element => \&help,
             help => 'When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.' },
  );

=head2 block_interval

The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry

=cut

has_field 'block_interval' =>
  (
    type => 'Duration',
    label => 'Block Interval',
    #Use the inflate method from pfappserver::Form::Field::Duration
    validate_when_empty => 1,
    default_method => sub {
        pfappserver::Form::Field::Duration->duration_inflate($pf::constants::Connection::Profile::BLOCK_INTERVAL_DEFAULT_VALUE)
    },
    tags => { after_element => \&help,
             help => 'The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.' },
  );

=head2 sms_pin_retry_limit

The amount of times a pin can try use a pin

=cut

has_field 'sms_pin_retry_limit' =>
  (
    type => 'PosInteger',
    label => 'SMS Pin Retry Limit',
    default => 0,
    tags => { after_element => \&help,
             help => 'Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.' },

  );

=head2 login_attempt_limit

The amount of login attempts allowed per mac

=cut

has_field 'login_attempt_limit' =>
  (
    type => 'PosInteger',
    label => 'Login Attempt Limit',
    default => 0,
    tags => { after_element => \&help,
             help => 'Limit the number of login attempts. A value of 0 disables the limit.' },
  );

=head2 sms_request_limit

The amount of sms request allowed per mac

=cut

has_field 'sms_request_limit' =>
  (
    type => 'PosInteger',
    label => 'SMS Request Retry Limit',
    default => 0,
    tags => { after_element => \&help,
             help => 'Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit.' },

  );

=head2 scan

Collection Scan engines for the profile

=cut

has_field 'scans' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
  );

=head2 scan.contains

The definition for Scan Sources field

=cut

has_field 'scans.contains' =>
  (
    type => 'Select',
    options_method => \&options_scan,
    widget_wrapper => 'DynamicTableRow',
  );

=head2 device_registration

The definition for Device registration Sources field

=cut

has_field 'device_registration' =>
  (
    type => 'Select',
    options_method => \&options_device_registration,
  );


=head2 preregistration

Controls whether or not this connection profile is used for preregistration

=cut

has_field 'access_registration_when_registered' =>
  (
   type => 'Toggle',
   label => 'Allow access to registration portal when registered',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.' },
  );


=head1 METHODS

=head2 options_locale

=cut

sub options_locale {
    return map { { value => $_, label => $_ } } @WEB::LOCALES;
}

=head2 options_sources

Returns the list of sources to be displayed

=cut

sub options_sources {
    return map { { value => $_->id, label => $_->id, attributes => { 'data-source-class' => $_->class  } } } grep { !$_->isa("pf::Authentication::Source::AdminProxySource") } @{getAllAuthenticationSources()};
}

=head2 options_billing_tiers

Returns the list of sources to be displayed

=cut

sub options_billing_tiers {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::BillingTiers->new->readAllIds};
}

=head2 options_provisioners

Returns the list of sources to be displayed

=cut

sub options_provisioners {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Provisioning->new->readAllIds};
}

=head2 options_scan

Returns the list of scan to be displayed

=cut

sub options_scan {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Scan->new->readAllIds};
}

=head2 options_device_registration

Returns the list of device_registration profile to be displayed

=cut

sub options_device_registration {
    return  map { { value => $_, label => $_ } } '',@{pf::ConfigStore::DeviceRegistration->new->readAllIds};
}


=head2 options_root_module

Returns the list of root modules to be displayed

=cut

sub options_root_module {
    my $cs = pf::ConfigStore::PortalModule->new;
    return map { $_->{type} eq "Root" ? { value => $_->{id}, label => $_->{description} } : () } @{$cs->readAll("id")};
}

=head2 validate

Remove duplicates and make sure only one external authentication source is selected for each type.

=cut

sub validate {
    my $self = shift;

    my @uniq_locales = uniq @{$self->value->{'locale'}};
    $self->field('locale')->value(\@uniq_locales);

    my @uniq_sources = uniq @{$self->value->{'sources'}};
    my %sources = map { $_ => 1 } @uniq_sources;
    $self->field('sources')->value(\@uniq_sources);

    my %external;
    foreach my $source_id (@uniq_sources) {
        my $source = pf::authentication::getAuthenticationSource($source_id);
        next unless $source && $source->class eq 'external';
        $external{$source->{'type'}} = 0 unless (defined $external{$source->{'type'}});
        $external{$source->{'type'}}++;
        if ($external{$source->{'type'}} > 1) {
            $self->field('sources')->add_error('Only one authentication source of each external type can be selected.');
            last;
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

