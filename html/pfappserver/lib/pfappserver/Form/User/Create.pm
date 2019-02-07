package pfappserver::Form::User::Create;

=head1 NAME

pfappserver::Form::User::Create - Common Web form for a user account

=head1 DESCRIPTION

Common form definition to create one ore many user accounts. This form is intended
to be used along the other forms (Create::Singe, Create::Multiple, Create:;Import).

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form::Authentication::Action';
use List::Util qw(first);
use List::MoreUtils qw(none);
use pf::admin_roles;
use pf::log;
use DateTime;
has '+source_type' => ( default => 'SQL' );

# Form fields
has_field 'valid_from' =>
  (
   type => 'DatePicker',
   required => 1,
   default_method => sub { DateTime->now->ymd() },
  );

has_field 'expiration' =>
  (
   type => 'DatePicker',
   required => 1,
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

sub build_block_list {
    my ($self) = @_;
    my @options_actions = $self->_get_allowed_options('allowed_actions');
    unless (@options_actions) {
        @options_actions = map {@$_} values %Actions::ACTIONS;
    }
    return [{
            name => 'templates',
            tag         => 'div',
            render_list => [
                map({"${_}_action"} @options_actions),   # the field are defined in the super class
            ],
            attr  => {id => 'templates'},
            class => ['hidden'],
        }
      ];
}

=head2 validate

Validate the following constraints :

 - an access duration and an unregistration date cannot be set at the same time
 - when setting a role, an access duration or an unregistration date is set
 - at least a role, a sponsor, or an access level is set

See pfappserver::Form::Authentication::Rule->validate

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    my @actions;

    @actions = grep { $_->{type} eq $Actions::SET_ACCESS_DURATION } @{$self->value->{actions}};
    if (scalar @actions > 0) {
        @actions = grep { $_->{type} eq $Actions::SET_UNREG_DATE } @{$self->value->{actions}};
        if (scalar @actions > 0) {
            $self->field('actions')->add_error("You can't define an access duration and an unregistration date at the same time.");
        }
    }

    @actions = grep { $_->{type} eq $Actions::SET_ROLE } @{$self->value->{actions}};
    if (scalar @actions > 0) {
        @actions = grep { $_->{type} eq $Actions::SET_ACCESS_DURATION || $_->{type} eq $Actions::SET_UNREG_DATE ||  $_->{type} eq $Actions::SET_TIME_BALANCE}
          @{$self->value->{actions}};
        if (scalar @actions == 0) {
            $self->field('actions')->add_error("You must set an access duration or an unregistration date when setting a role.");
        }
    }

    @actions = grep {
        $_->{type} eq $Actions::SET_ROLE || $_->{type} eq $Actions::MARK_AS_SPONSOR || $_->{type} eq $Actions::SET_ACCESS_LEVEL
    } @{$self->value->{actions}};
    if (scalar @actions == 0) {
        $self->field('actions')->add_error("You must at least set a role, mark the user as a sponsor, or set an access level.");
    }
    $self->_check_allowed_actions("Action(s) provided is not an allowed action");
    $self->_check_allowed_unreg_date("Unregistration date provided is after the maximum allowed.");
    $self->_check_allowed_options($Actions::SET_ACCESS_DURATION,'allowed_access_durations',"Access Duration provided is not an allowed access duration");
    $self->_check_allowed_options($Actions::SET_ACCESS_LEVEL,'allowed_access_levels',"Access Level provided is not an allowed access level");
    $self->_check_allowed_options($Actions::SET_ROLE,'allowed_roles',"Role provided is not an allowed role");
}

=head2 _check_allowed_unreg_date

check to see the unregdate in the actions can be set according to the user role

=cut

sub _check_allowed_unreg_date {
    my ($self, $error_msg) = @_;
    if ( my $action = first { $_->{type} eq $Actions::SET_UNREG_DATE } @{$self->value->{actions}} ) {
        unless(check_allowed_unreg_date([$self->ctx->user->roles], $action->{value})){
            $self->field('actions')->add_error($error_msg);
        }
    }
}

sub _check_allowed_actions {
    my ($self, $error_msg) = @_;
    my %actions = map { $_ => undef } admin_allowed_options([$self->ctx->user->roles], 'allowed_actions');
    if (keys %actions) {
        foreach my $action (grep { !exists $actions{$_->{type}}} @{$self->value->{actions}}) {
            $self->field('actions')->add_error($error_msg);
        }
    }
}


=head2 _check_allowed_options

check to see the passed action value is a valid value for the user role

=cut

sub _check_allowed_options {
    my ($self, $action, $option, $error_msg) = @_;
    if (my $action = first {$_->{type} eq $action} @{$self->value->{actions}}) {
        my @options = admin_allowed_options([$self->ctx->user->roles], $option);
        if (@options && none {$_ eq $action->{value}} @options) {
            $self->field('actions')->add_error($error_msg);
        }
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
