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

use HTTP::Status qw(:constants is_success);
use pf::config;
use pf::util qw(get_abbr_time);
use pf::web::util;
use pf::Authentication::constants;
use pf::Authentication::Action;

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
  );

# The templates block contains the dynamic fields of the rule definition.
#
# The following fields depend on the selected condition attribute :
#  - the condition operators select fields
#  - the condition value fields
# The following fields depend on the selected action type :
#  - the action value fields
#
# The field substitution is made through JavaScript.

has_field "${Actions::MARK_AS_SPONSOR}_action" =>
  (
   type => 'Hidden',
   default => '1',
  );
has_field "${Actions::SET_ACCESS_LEVEL}_action" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&options_access_level,
  );
has_field "${Actions::SET_ROLE}_action" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&options_roles,
  );

#Adding default method for ${Actions::SET_ACCESS_DURATION}_action to always use the current value of the guests_admin_registration.default_access_duration

__PACKAGE__->meta->add_method(
    "default_${Actions::SET_ACCESS_DURATION}_action" => sub {
        return get_abbr_time($Config{'guests_admin_registration'}{'default_access_duration'});
    }
);

has_field "${Actions::SET_ACCESS_DURATION}_action" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&options_durations,
  );
has_field "${Actions::SET_UNREG_DATE}_action" =>
  (
   type => 'DatePicker',
   do_label => 0,
   wrapper => 0,
  );

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
        $actions_ref = $classname->available_actions();
        @actions = map { $_ => $self->_localize($_) } @{$actions_ref};
    }

    return @actions;
}

=head2 options_access_level

Populate the select field for the 'access level' template action.

=cut

sub options_access_level {
    my $self = shift;

    return
      (
       {
        label => $self->_localize('None'),
        value => $WEB_ADMIN_NONE,
       },
       {
        label => $self->_localize('All'),
        value => $WEB_ADMIN_ALL,
       },
      );
}

=head2 options_roles

Populate the select field for the roles template action.

=cut

sub options_roles {
    my $self = shift;

    my @roles;

    # Build a list of existing roles
    my ($status, $result) = $self->form->ctx->model('Roles')->list();
    if (is_success($status)) {
        @roles = map { $_->{name} => $_->{name} } @$result;
    }

    return @roles;
}

=head2 options_durations

Populate the access duration select field with the available values defined
in the pf.conf configuration file.

=cut

sub options_durations {
    my $self = shift;

    my $durations = pf::web::util::get_translated_time_hash(
        [ split (/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'}) ],
        $self->form->ctx->languages()->[0]
    );
    my @options = map { get_abbr_time($_) => $durations->{$_} } sort { $a <=> $b } keys %$durations;

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
