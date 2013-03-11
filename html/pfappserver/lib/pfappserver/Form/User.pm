package pfappserver::Form::User;

=head1 NAME

pfappserver::Form::User - Web form for a user

=head1 DESCRIPTION

Form definition to update a user.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';
use pf::config;
use pf::util qw(get_abbr_time);
use HTTP::Status qw(:constants is_success);

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

# Form fields
has_field 'pid' =>
  (
   type => 'Uneditable',
   label => 'Username',
  );

has_field 'firstname' =>
  (
   type => 'Text',
   label => 'Firstname',
  );

has_field 'lastname' =>
  (
   type => 'Text',
   label => 'Lastname',
  );

has_field 'company' =>
  (
   type => 'Text',
   label => 'Company',
  );

has_field 'email' =>
  (
   type => 'Email',
   label => 'Email',
   required => 1,
  );

has_field 'address' =>
  (
   type => 'TextArea',
   label => 'Address',
  );

has_field 'notes' =>
  (
   type => 'TextArea',
   label => 'Notes',
  );

has_field 'sponsor' =>
  (
   type => 'Text',
   label => 'Sponsor',
  );

has_field "actions" =>
  (
    type => 'Compound',
  );

has_field "actions.pid" =>
  (
   type => 'Text',
   widget => 'NoRender',
  );

has_field "actions.sponsor" =>
  (
   type => 'Toggle',
   label => 'Is a Sponsor',
   checkbox_value => '1',
   uncheckbox_value => '0',
  );

has_field "actions.access_level" =>
  (
   type => 'Select',
   'label' => 'Access Level',
   options_method => \&options_access_level,
  );

has_field "actions.role" =>
  (
   type => 'Select',
   label => 'Role',
   options_method => \&options_roles,
  );

has_field "actions.access_duration" =>
  (
   type => 'Select',
   label => 'Access Duration',
   options_method => \&options_durations,
   default => get_abbr_time($Config{'guests_admin_registration'}{'default_access_duration'}),
  );

has_field "actions.unreg_date" =>
  (
   type  => 'DatePicker',
   label => 'Unregistration Date',
  );

has_field "actions.sponsor" =>
  (
   type => 'Toggle',
   label => 'Is a Sponsor',
   checkbox_value => '1',
   uncheckbox_value => '0',
  );

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
