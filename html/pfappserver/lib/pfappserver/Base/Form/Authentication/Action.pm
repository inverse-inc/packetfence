package pfappserver::Base::Form::Authentication::Action;

=head1 NAME

pfappserver::Base::Form::Rule - Common Web form parameters related to user rules

=head1 DESCRIPTION

Common form definition to define actions related to a user or a users source.
This form is intended to be used along other forms (User::Create,
Authentication::Rule).

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::AllowedOptions',
     'pfappserver::Role::Form::RolesAttribute';

use HTTP::Status qw(:constants is_success);
use List::MoreUtils qw(uniq);
use pf::config qw(%Config);
use pf::web::util;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::admin_roles;
use pf::log;
use pf::constants::config qw($TIME_MODIFIER_RE);

has 'source_type' => ( is => 'ro' );

# Form fields
has_field 'actions' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'actions.type' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   localize_labels => 1,
   options_method => \&options_actions,
  );
has_field 'actions.value' =>
  (
   type => 'Hidden',
   required => 1,
   messages => { required => 'Make sure all the actions are properly defined.' },
   deflate_value_method => sub {
     my ( $self, $value ) = @_;
     return ref($value) ? join(",",@{$value}) : $value ;
   },
  );


our %ACTION_FIELD_OPTIONS = (
    $Actions::MARK_AS_SPONSOR => {
        type    => 'Hidden',
        default => '1'
    },
    $Actions::SET_ACCESS_LEVEL => {
        type          => 'Select',
        do_label      => 0,
        wrapper       => 0,
        multiple      => 1,
        element_class => ['chzn-select'],
        element_attr => {'data-placeholder' => 'Click to add a access right'},
        options_method => \&options_access_level,
    },
    $Actions::SET_TENANT_ID => {
        type          => 'Text',
        do_label      => 0,
        wrapper       => 0,
    },
    $Actions::SET_ROLE => {
        type           => 'Select',
        do_label       => 0,
        wrapper        => 0,
        element_class => ['chzn-deselect'],
        options_method => \&options_roles,
    },
    $Actions::SET_ACCESS_DURATION => {
        type           => 'Select',
        do_label       => 0,
        wrapper        => 0,
        options_method => \&options_durations,
        default_method => sub { $Config{'guests_admin_registration'}{'default_access_duration'} }
    },
    $Actions::SET_UNREG_DATE => {
        type     => 'DatePicker',
        do_label => 0,
        wrapper  => 0,
    },
    $Actions::SET_TIME_BALANCE => {
        type           => 'Select',
        do_label       => 0,
        wrapper        => 0,
        options_method => \&options_durations_absolute,
        default_method => sub { $Config{'guests_admin_registration'}{'default_access_duration'} }
    },
    $Actions::SET_BANDWIDTH_BALANCE => {
        type           => 'Text',
        do_label       => 0,
        wrapper        => 0,
    },
);

=head2 field_list

Dynamically build the list of available actions corresponding to the
authentication source type.

=cut

sub field_list {
    my $self = shift;

    my ($classname, $actions_ref, @fields);

    $classname = 'pf::Authentication::Source::' . $self->form->source_type . 'Source';
    eval "require $classname";
    if ($@) {
        $self->form->ctx->log->error($@);
    }
    else {
        @fields = map { exists $ACTION_FIELD_OPTIONS{$_} ? ( "${_}_action" => $ACTION_FIELD_OPTIONS{$_}) : () } @{$classname->available_actions()};
    }

    return \@fields;
}

=head2 options_actions

Populate the actions select field with the available actions of the
authentication source.

=cut

sub options_actions {
    my $self = shift;

    my ($classname, $actions_ref, @actions);

    $classname = 'pf::Authentication::Source::' . $self->form->source_type . 'Source';
    eval "require $classname";
    if ($@) {
        $self->form->ctx->log->error($@);
    }
    else {
        my @allowed_actions = $self->form->_get_allowed_options('allowed_actions');
        unless (@allowed_actions) {
            @allowed_actions = @{$classname->available_actions()};
        }
        @actions = map { 
          { value => $_, 
            label => $self->_localize($_), 
            attributes => { 'data-rule-class' => pf::Authentication::Action->getRuleClassForAction($_) } 
          } 
        } @allowed_actions;
    }

    return @actions;
}

=head2 options_access_level

Populate the select field for the 'access level' template action.

=cut

sub options_access_level {
    my $self = shift;
    my @options_values = $self->form->_get_allowed_options('allowed_access_levels');
    unless( @options_values ) {
        @options_values = keys %ADMIN_ROLES;
    }
    return map { {value => $_, label => $self->_localize($_) } } @options_values;
}

=head2 options_roles

Populate the select field for the roles template action.

=cut

sub options_roles {
    my $self = shift;
    my @options_values = $self->form->_get_allowed_options('allowed_roles');
    unless( @options_values ) {
        my $result = $self->form->roles;
        @options_values = map { $_->{name} } @$result;
    }
    # Build a list of existing roles
    return map { { value => $_, label => $_ } } @options_values;
}

=head2 options_durations

Populate the access duration select field with the available values defined
in the pf.conf configuration file.

=cut

sub options_durations {
    my $self = shift;
    my @options_values = $self->form->_get_allowed_options('allowed_access_durations');
    my $durations;
    if(@options_values) {
        $durations = pf::web::util::get_translated_time_hash(
            \@options_values,
            $self->form->languages()->[0]
        );
    } else {
        my $default_choices = $Config{'guests_admin_registration'}{'access_duration_choices'};
        my @choices = uniq admin_allowed_options_all([$self->form->user_roles],'allowed_access_durations'), split (/\s*,\s*/, $default_choices);
        $durations = pf::web::util::get_translated_time_hash(
            \@choices,
            $self->form->languages()->[0]
        );
    }
    my @options = map { $durations->{$_}[0] => $durations->{$_}[1] } sort { $a <=> $b } keys %$durations;

    return \@options;
}

=head2 options_durations_absolute

Populate the absolute access duration select field with the available values defined
in the pf.conf configuration file.

=cut

sub options_durations_absolute {
    my $self = shift;
    my @options_values = $self->form->_get_allowed_options('allowed_access_durations');
    @options_values = grep { $_ =~ /^(\d+)($TIME_MODIFIER_RE)$/} @options_values;
    my $durations;
    if(@options_values) {
        $durations = pf::web::util::get_translated_time_hash(
            \@options_values,
            $self->form->languages()->[0]
        );
    } else {
        my $default_choices = $Config{'guests_admin_registration'}{'access_duration_choices'};
        my @choices = uniq admin_allowed_options_all([$self->form->user_roles],'allowed_access_durations'), split (/\s*,\s*/, $default_choices);
        @choices = grep { $_ =~ /^(\d+)($TIME_MODIFIER_RE)$/} @choices;
        $durations = pf::web::util::get_translated_time_hash(
            \@choices,
            $self->form->languages()->[0]
        );
    }
    my @options = map { $durations->{$_}[0] => $durations->{$_}[1] } sort { $a <=> $b } keys %$durations;

    return \@options;
}

=head2 validate

Validate that each action is defined only once.

=cut

sub validate {
    my $self = shift;

    my %actions;
    foreach my $action (@{$self->value->{actions}}) {
        $actions{$action->{type}}++;
    }
    my @duplicates = grep { $actions{$_} > 1 } keys %actions;
    if (scalar @duplicates > 0) {
        $self->field('actions')->add_error("You can't have more than one action of the same type.");
    }
    foreach my $action (@{$self->value->{actions}}) {
        get_logger->info($action->{type});
    }
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
