package pfappserver::Form::Violation;

=head1 NAME

pfappserver::Form::Violation - Web form for a violation

=head1 DESCRIPTION

Form definition to create or update a violation.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

use HTTP::Status qw(:constants is_success);

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

# Form select options
has 'actions' => ( is => 'ro' );
has 'violations' => ( is => 'ro' );
has 'triggers' => ( is => 'ro' );
has 'templates' => ( is => 'ro' );

# Form fields
has_field 'enabled' =>
  (
   type => 'Toggle',
   widget => 'Switch',
   label => 'Enabled',
  );
has_field 'id' =>
  (
   type => 'PosInteger',
   label => 'Identifier',
   required => 1,
   messages => { required => 'Please specify an identifier for the violation.' },
   tags => { after_element => \&help,
             help => 'Use an number above 150000 if you want to be able to delete this violation later.' },
  );
has_field 'desc' =>
  (
   type => 'Text',
   label => 'Description',
   required => 1,
   element_class => ['input-large'],
   messages => { required => 'Please specify a brief description of the violation.' },
  );
has_field 'actions' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Actions',
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add an action' }
  );
has_field 'vclose' =>
  (
   type => 'Select',
   label => 'Violation to close',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'No violation'},
   tags => { after_element => \&help,
             help => 'When selecting the <strong>close</strong> action, triggering the violation will close the one you select in the vclose field. This is an experimental workflow for Mobile Device Management (MDM).' },
  );
has_field 'priority' =>
  (
   type => 'IntRange',
   label => 'Priority',
   range_start => 1,
   range_end => 10,
   tags => { after_element => \&help,
             help => 'Range 1-10, with 1 the higest priority and 10 the lowest. Higher priority violations will be addressed first if a host has more than one.' },
  );
has_field 'whitelisted_categories' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Whitelisted Roles',
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles won\'t be affected by a violation of this type.' },
  );
has_field 'trigger' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Triggers',
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add a trigger' },
#   tags => { after_element => \&help,
#             help => 'Method to reference external detection methods such as Detect (SNORT), Nessus, OpenVAS, OS (DHCP Fingerprint Detection), USERAGENT (Browser signature), VENDORMAC (MAC address class), etc.' },
  );
has_field 'auto_enable' =>
  (
   type => 'Toggle',
   label => 'Auto Enable',
   tags => { after_element => \&help,
             help => 'Specifies if a host can self remediate the violation (enable network button) or if they can not and must call the help desk.' },
  );
has_field 'max_enable' =>
  (
   type => 'PosInteger',
   label => 'Max Enables',
   tags => { after_element => \&help,
             help => 'Number of times a host will be able to try and self remediate before they are locked out and have to call the help desk. This is useful for users who just <i>click through</i> violation pages.'},
  );
has_field 'grace' =>
  (
   type => 'Duration',
   label => 'Grace',
   tags => { after_element => \&help,
             help => 'Amount of time before the violation can reoccur. This is useful to allow hosts time (in the example 2 minutes) to download tools to fix their issue, or shutoff their peer-to-peer application.' },
  );
has_field 'window_dynamic' =>
  (
   type => 'Checkbox',
   label => 'Dynamic Window',
   checkbox_value => 'dynamic',
   tags => { after_element => \&help,
             help => 'Only works for accounting violations.  The violation will be opened according to the time you set in the accounting violation (ie. You have an accounting violation for 10GB/month.  If you bust the bandwidth after 3 days, the violation will open and the release date will be set for the last day of the current month).' },
  );
has_field 'window' =>
  (
   type => 'Duration',
   label => 'Window',
   tags => { after_element => \&help,
             help => 'Amount of time before a violation will be closed automatically. Instead of allowing people to reactivate the network, you may want to open a violation for a defined amount of time instead.' },
  );
has_field 'template' =>
  (
   type => 'Select',
   label => 'Template',
   tags => { after_element => \&help,
             help => 'HTML template the host will be redirected to while in violation. You can create new templates from the <em>Portal Profiles</em> configuration section.' }
  );
has_field 'button_text' =>
  (
   type => 'Text',
   label => 'Button Text',
   tags => { after_element => \&help,
             help => 'Text displayed on the violation form to hosts.' },
  );
has_field 'vlan' =>
  (
   type => 'Text',
   label => 'Target VLAN',
   tags => { after_element => \&help,
             help => 'Destination VLAN where PacketFence should put the client when a violation of this type is open.' }
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

=head2 options_actions

=cut

sub options_actions {
    my $self = shift;

    # $self->actions comes from pfappserver::Model::Config::Violations->availableActions
    my @actions = map { $_ => $self->actions->{$_} } keys %{$self->actions} if ($self->actions);

    return @actions;
}

=head2 options_vclose

=cut

sub options_vclose {
    my $self = shift;

    # $self->violations comes from pfappserver::Model::Config::Violations->read_violation
    my @violations = map { $_->{id} => $_->{desc} || $_->{id} } @{$self->violations} if ($self->violations);

    return ('' => '', @violations);
}

=head2 options_whitelisted_categories

Populate the select field for the whitelisted roles.

=cut

sub options_whitelisted_categories {
    my $self = shift;

    my @roles;

    # Build a list of existing roles
    my ($status, $result) = $self->form->ctx->model('Roles')->list();
    if (is_success($status)) {
        @roles = map { $_->{name} => $_->{name} } @$result;
    }

    return @roles;
}

=head2 options_trigger

=cut

sub options_trigger {
    my $self = shift;

    # $self->triggers comes from pfappserver::Model::Config::Violations->list_triggers
    my @triggers = map { $_ => $_ } @{$self->triggers} if ($self->triggers);

    return @triggers;
}

=head2 options_template

=cut

sub options_template {
    my $self = shift;

    my @templates = map { $_ => "$_.html" } @{$self->templates} if ($self->templates);

    return @templates;
}

=head2 validate

=cut

sub validate {
    my $self = shift;

    # If the close action is selected, make sure a valid closing violation (vclose) is specified
    if (grep {$_ eq 'close'} @{$self->value->{actions}}) {
        my $vclose = $self->value->{vclose};
        my @vids = map { $_->{id} } @{$self->violations};
        unless (defined $vclose && grep {$_ eq $vclose} @vids) {
            $self->field('vclose')->add_error('Specify a violation to close.');
        }
    }
}

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
