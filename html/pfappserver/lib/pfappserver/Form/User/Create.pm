package pfappserver::Form::User::Create;

=head1 NAME

pfappserver::Form::User::Create - Common Web form for a user account

=head1 DESCRIPTION

Common form definition to create one ore many user accounts. This form is intended
to be used along the other forms (Create::Singe, Create::Multiple, Create:;Import).

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

use HTTP::Status qw(:constants is_success);
use pf::config;
use pf::util qw(get_abbr_time get_translatable_time);
use pf::web::guest;
use pf::web::util;
use pf::Authentication::constants;
use pf::Authentication::Action;

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );
has 'roles' => ( is => 'ro' );

# Form fields
has_field 'arrival_date' =>
  (
   type => 'DatePicker',
   label => 'Arrival Date',
   required => 1,
   start => &now,
  );
has_field 'access_duration' =>
  (
   type => 'Select',
   label => 'Access Duration',
   required => 1,
   options_method => \&options_durations,
   default => get_abbr_time($Config{'guests_admin_registration'}{'default_access_duration'}),
  );
has_field 'actions' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'actions.type' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   options_method => \&options_actions,
  );
has_field 'actions.value' =>
  (
   type => 'Hidden',
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

has_block 'templates' =>
  (
   tag => 'div',
   render_list => [
                   map( { "${_}_action" } @Actions::ACTIONS),
                  ],
   attr => { id => 'templates' },
   class => [ 'hidden' ],
  );
has_field "${Actions::MARK_AS_SPONSOR}_action" =>
  (
   type => 'Hidden',
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
has_field "${Actions::SET_UNREG_DATE}_action" =>
  (
   type => 'DatePicker',
   do_label => 0,
   wrapper => 0,
  );

=head2 options_actions

Populate the access duration select field with the available values defined
in the pf.conf configuration file.

=cut

sub options_durations {
    my $self = shift;

    my $durations = pf::web::util::get_translated_time_hash(
        [ split (/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'}) ], 
        $self->form->ctx->languages()->[0]
    );
    my @options = map { get_abbr_time($_) => $durations->{$_} } sort { $a <=> $b } keys $durations;

    return \@options;
}

=head2 options_actions

Populate the actions select field with the available actions of the
authentication source.

=cut

sub options_actions {
    my $self = shift;

    my $actions_ref = pf::Authentication::Action::availableActions();
    my @actions = map { $_ => $self->_localize($_) } @{$actions_ref};

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

=head2 now

Return the current day, used as the minimal date of the arrival date.

=cut

sub now {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    return sprintf "%d-%02d-%02d", $year+1900, $mon+1, $mday;
}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
