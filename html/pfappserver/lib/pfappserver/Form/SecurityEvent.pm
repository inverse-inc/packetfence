package pfappserver::Form::SecurityEvent;

=head1 NAME

pfappserver::Form::SecurityEvent - Web form for a security event

=head1 DESCRIPTION

Form definition to create or update a security event.

=cut

use HTML::FormHandler::Moose;
use pfappserver::Base::Form::Authentication::Action;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

use HTTP::Status qw(:constants is_success);
use List::MoreUtils qw(uniq);
use pf::config qw(%Config);
use pf::web::util;
use pf::admin_roles;
use pf::action;
use pf::log;
use pf::constants::security_event qw($MAX_SECURITY_EVENT_ID %NON_WHITELISTABLE_ROLES);
use pf::class qw(class_next_security_event_id);

# Form select options
has 'security_events' => ( is => 'ro' );
has 'triggers' => ( is => 'ro' );
has 'templates' => ( is => 'ro' );
has 'placeholders' => ( is => 'ro' );

# Form fields
has_field 'enabled' =>
  (
   type => 'Toggle',
   widget => 'Switch',
   label => 'Enabled',
  );
has_field 'id' =>
  (
   type => 'Text',
   label => 'Identifier',
   default_method => \&class_next_security_event_id,
   messages => { required => 'Please specify an identifier for the security event.' },
   tags => { after_element => \&help,
             help => 'Use a number above 1500000 if you want to be able to delete this security event later.' },
  );
has_field 'desc' =>
  (
   type => 'Text',
   label => 'Description',
   required_when => {
    id => sub { $_[0] ne 'defaults' }
   },
   element_class => ['input-large'],
   messages => { required => 'Please specify a brief description of the security event.' },
  );
has_field 'actions' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Actions',
   localize_labels => 1,
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add an action' }
  );
has_field 'user_mail_message' =>
  (
   type => 'TextArea',
   label => 'Additionnal message for the user',
   element_class => ['input-large'],
   tags => { after_element => \&help, 
             help => 'A message that will be added to the e-mail sent to the user regarding this security event.' }, 
  );

has_field 'triggers' => (
    type => 'Repeatable',
    inactive => 1,
    accessor => 'trigger',
    inflate_default_method => sub {
        my ( $f, $v ) = @_;
        ref($v) eq 'ARRAY' ? $v : [ split( /\s*,\s*/, $v ) ];
    },
    deflate_value_method => sub {
        my ( $f, $v ) = @_;
        ref($v) eq 'ARRAY' ? join(',', @$v) : $v;
    }
);

has_field 'triggers.contains' => (
    type => 'Trigger',
);

has_field 'vclose' =>
  (
   type => 'Select',
   label => 'Security Event to close',
   element_class => ['chzn-deselect hide'],
   element_attr => {'data-placeholder' => 'Select a security event'},
   tags => { after_element => \&help,
             help => 'When selecting the <strong>close</strong> action, triggering the security event will close this security event. This is an experimental workflow for Mobile Device Management (MDM).' },
  );
has_field 'target_category' =>
  (
   type => 'Select',
   label => 'Set role',
   options_method => \&options_roles,
   element_class => ['chzn-deselect hide'],
   element_attr => {'data-placeholder' => 'Select a role'},
   tags => { after_element => \&help,
             help => 'When selecting the <strong>role</strong> action, triggering the security event will change the node to this role.' },
  );
has_field 'priority' =>
  (
   type => 'IntRange',
   label => 'Priority',
   range_start => 1,
   range_end => 10,
   tags => { after_element => \&help,
             help => 'Range 1-10, with 1 the higest priority and 10 the lowest. Higher priority security events will be addressed first if a host has more than one.' },
  );
has_field 'whitelisted_roles' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Whitelisted Roles',
   options_method => \&options_whitelisted_roles,
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles won\'t be affected by a security event of this type.' },
  );
has_field 'trigger' =>
  (
   label =>"Trigger",
   type => 'TextArea',
  );
has_field 'auto_enable' =>
  (
   type => 'Toggle',
   label => 'Auto Enable',
   tags => { after_element => \&help,
             help => 'Specifies if a host can self remediate the security event (enable network button) or if they can not and must call the help desk.' },
  );
has_field 'max_enable' =>
  (
   type => 'PosInteger',
   label => 'Max Enables',
   tags => { after_element => \&help,
             help => 'Number of times a host will be able to try and self remediate before they are locked out and have to call the help desk. This is useful for users who just <i>click through</i> security event pages.'},
  );
has_field 'grace' =>
  (
   type => 'Duration',
   label => 'Grace',
   tags => { after_element => \&help,
             help => 'Amount of time before the security event can reoccur. This is useful to allow hosts time (in the example 2 minutes) to download tools to fix their issue, or shutoff their peer-to-peer application.' },
  );
has_field 'window_dynamic' =>
  (
   type => 'Checkbox',
   label => 'Dynamic Window',
   checkbox_value => 'dynamic',
   tags => { after_element => \&help,
             help => 'Only works for accounting security events.  The security event will be opened according to the time you set in the accounting security event (ie. You have an accounting security event for 10GB/month.  If you bust the bandwidth after 3 days, the security event will open and the release date will be set for the last day of the current month).' },
  );
has_field 'window' =>
  (
   type => 'Duration',
   label => 'Window',
   tags => { after_element => \&help,
             help => 'Amount of time before a security event will be closed automatically. Instead of allowing people to reactivate the network, you may want to open a security event for a defined amount of time instead.' },
  );
has_field 'delay_by' =>
  (
   type => 'Duration',
   label => 'Delay By',
   tags => { after_element => \&help,
             help => "Delay before triggering the security event." },
  );
has_field 'template' =>
  (
   type => 'Select',
   label => 'Template',
   tags => { after_element => \&help,
             help => 'HTML template the host will be redirected to while in security event. You can create new templates from the <em>Connection Profiles</em> configuration section.' }
  );
has_field 'button_text' =>
  (
   type => 'Text',
   label => 'Button Text',
   tags => { after_element => \&help,
             help => 'Text displayed on the security event form to hosts.' },
  );
has_field 'vlan' =>
  (
   type => 'Select',
   label => 'Role',
   options_method => \&options_roles,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Select a Role'},
   tags => { after_element => \&help,
             help => 'Destination Role where PacketFence should put the client when a security event of this type is open (only for <em>Change network access on security event</em> action).' }
  );
has_field 'redirect_url' =>
  (
   type => 'Text',
   label => 'Redirection URL',
   tags => { after_element => \&help,
             help => 'Destination URL where PacketFence will forward the device. By default it will use the Redirection URL from the connection profile configuration.' }
  );
has_field 'external_command' =>
  (
   type => 'Text',
   label => 'External Command',
   element_class => ['input-large'],
   messages => { required => 'Please specify the command you want to execute.' },
  );
has_field 'access_duration' =>
  (
   type => 'Select',
   label => 'Access Duration',
   localize_labels => 1,
   options_method => \&pfappserver::Base::Form::Authentication::Action::options_durations,
   default_method => sub { $Config{'guests_admin_registration'}{'default_access_duration'} },
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add a duration'},
   tags => { after_element => \&help,
             help => 'Specify the access duration for the new registered node.' },
  );

=head2 around has_errors

Ignore validation errors for the trigger select field. An error would occur if a new trigger is added from the Web
interface. In this case, this new value is not in the initial options list and would cause the form to throw an error.

=cut

around 'has_errors'  => sub {
    my ( $orig, $self ) = @_;

    if ($self->$orig()) {
        my @error_fields = $self->error_fields;
        if (scalar @error_fields == 1 && $error_fields[0]->name eq 'trigger') {
            return 0;
        }
    }

    return $self->$orig;
};

=head2 update_fields

For security events other than the default, add placeholders with values from default security event.

=cut

sub update_fields {
    my $self = shift;

    unless ($self->{init_object} && defined $self->init_object->{id} && $self->init_object->{id} eq 'defaults') {
        if ($self->placeholders) {
            foreach my $field ($self->fields) {
                if ($self->placeholders->{$field->name} && length $self->placeholders->{$field->name}) {
                    if (!ref $self->placeholders->{$field->name}
                        && $field->type eq 'Select'
                        && $field->options->[0]->{'value'} eq '') {
                        # Add a placeholder for select menus that can be unselected
                        my $val = sprintf "%s (%s)", $self->_localize('Default'), $self->placeholders->{$field->name};
                        $field->element_attr({ 'data-placeholder' => $val });
                    }
                    elsif ($field->name !~ m/^(id|enabled|desc)$/ && $field->type eq 'Text') {
                        # Add a placeholder for text fields other than 'id', 'enabled' and 'desc'
                        $field->element_attr({ placeholder => $self->placeholders->{$field->name} });
                    }
                }
            }
        }
    }

    $self->SUPER::update_fields();
}


=head2 options_actions

=cut

sub options_actions {
    my $self = shift;

    my @actions = map { $_ => $self->_localize("${_}_action") } @pf::action::SECURITY_EVENT_ACTIONS;

    return @actions;
}

=head2 options_vclose

=cut

sub options_vclose {
    my $self = shift;

    # $self->security_events comes from pfappserver::Model::Config::SecurityEvents->readAll
    my @security_events = map { $_->{id} => $_->{desc} || $_->{id} } @{$self->form->security_events} if ($self->form->security_events);

    return ('' => '', @security_events);
}

=head2 options_whitelisted_roles

The options for whitelisted roles

=cut

sub options_whitelisted_roles {
    my ($self) = @_;
    # NOTE: options_roles is a method on form but that receives the field as the first argument
    my %roles = options_roles($self);
    # Roles that aren't technically roles (non-db), except for registration which matches unregistered devices
    my %whitelisted_roles;
    foreach my $role (keys(%roles)) {
        next if(exists($NON_WHITELISTABLE_ROLES{$role}));
        $whitelisted_roles{$role} = $role;
    }
    return %whitelisted_roles;
}

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;

    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);

    return ('' => '', @roles);
}

=head2 options_template

=cut

sub options_template {
    my $self = shift;

    my @templates = map { $_ => "$_.html" } @{$self->form->templates} if ($self->form->templates);

    return @templates;
}

=head2 validate

Make sure the ID is a positive integer, unless its 'defaults'

Make sure a security event is specified if the close action is selected.

Make sure a role is specified if the role action is selected.

=cut

sub validate {
    my $self = shift;

    # If the close action is selected, make sure a valid closing security event (vclose) is specified
    if (grep {$_ eq 'close'} @{$self->value->{actions}}) {
        my $vclose = $self->value->{vclose};
        my @vids = map { $_->{id} } @{$self->security_events};
        unless (defined $vclose && grep {$_ eq $vclose} @vids) {
            $self->field('vclose')->add_error('Specify a security event to close.');
        }
    }

    # If the role action is selected, make sure a valid role (target_category) is specified
    if (grep {$_ eq 'role'} @{$self->value->{actions}}) {
        my $role = $self->value->{target_category};
        my $roles_ref = $self->roles;
        my @roles = map { $_->{name} } @$roles_ref;
        unless (defined $role && grep {$_ eq $role} @roles) {
            $self->field('target_category')->add_error('Specify a role to use.');
        }
    }
}

=head2 validate_id

Validate the ID is numeric and doesn't exceed 2000000000 (max int(11) is 2147483648 but we make it a pretty rounded number)

=cut

sub validate_id {
    my ($self, $field) = @_;
    my $val = $field->value;
    return if $val eq 'defaults';

    if($val <= 0 || $val > $MAX_SECURITY_EVENT_ID) {
        $field->add_error('The security event ID should be between 1 and 2000000000');
        return;
    }
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
