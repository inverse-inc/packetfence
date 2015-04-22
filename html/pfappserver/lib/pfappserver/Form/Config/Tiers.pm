package pfappserver::Form::Config::Tiers;

=head1 NAME
pfappserver::Form::Config::Tiers - Web form for an admin role
=head1 DESCRIPTION
Form definition to create or update an tier
=cut

use strict;
use warnings;
use pf::config;
use pf::admin_roles;
use List::MoreUtils qw(uniq);
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;

has 'roles' => ( is => 'ro' );

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Tier Name',
   required => 1,
   messages => { required => 'Please specify the name of the tier entry' },
  );

has_field 'price' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'The price for this tier.' },
  );


has_field 'timeout' =>
  (
   type           => 'Select',
   label       => 'Timeout',
   wrapper        => 0,
   options_method => \&options_durations,
   default_method => sub { $Config{'guests_admin_registration'}{'default_access_duration'} }

  );

has_field 'usage_duration' =>
  (
   type           => 'Select',
   label       => 'Usage duration',
   wrapper        => 0,
   options_method => \&options_durations,
   default_method => sub { $Config{'guests_admin_registration'}{'default_access_duration'} }
  );

has_field 'category' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Roles',
   options_method => \&options_roles,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will be affected' },
  );

has_field 'description' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'The price for this tier.' },
  );

has_block  definition =>
  (
    render_list => [qw(description price category timeout usage_duration)],
  );

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
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
            $self->form->ctx->languages()->[0]
        );
    } else {
        my $default_choices = $Config{'guests_admin_registration'}{'access_duration_choices'};
        my @choices = uniq admin_allowed_options_all([$self->form->ctx->user->roles],'allowed_access_durations'), split (/\s*,\s*/, $default_choices);
        $durations = pf::web::util::get_translated_time_hash(
            \@choices,
            $self->form->ctx->languages()->[0]
        );
    }
    my @options = map { $durations->{$_}[0] => $durations->{$_}[1] } sort { $a <=> $b } keys %$durations;

    return \@options;
}

=head2 _get_allowed_options

Get the allowed options for the current user based off their role.

=cut

sub _get_allowed_options {
    my ($self,$option) = @_;
    return admin_allowed_options([$self->ctx->user->roles],$option);
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my ($status, $roles) = $c->model('Roles')->list();
    return $self->SUPER::ACCEPT_CONTEXT($c, roles => $roles, @args);
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
