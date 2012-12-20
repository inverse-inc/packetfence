package pfappserver::Form::User::Create;

=head1 NAME

pfappserver::Form::User::Create - Common Web form for a user account

=head1 DESCRIPTION

Common form definition to create one ore many user accounts. This form is intended
to be used along the other forms (Create::Singe, Create::Multiple, Create:;Import).

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form::Authentication::Action';

# Form fields
has_field 'arrival_date' =>
  (
   type => 'DatePicker',
   label => 'Arrival Date',
   required => 1,
   start => &now,
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
                   map( { "${_}_action" } @Actions::ACTIONS), # the field are defined in the super class
                  ],
   attr => { id => 'templates' },
   class => [ 'hidden' ],
  );

=head2 now

Return the current day, used as the minimal date of the arrival date.

=cut

sub now {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    return sprintf "%d-%02d-%02d", $year+1900, $mon+1, $mday;
}

=head2 validate

Validate the following constraints :

 - an access duration and an unregistration date cannot be set at the same time
 - at least a role, an access duration, or an unregistration date is set

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    my @actions;
    @actions = grep { $_->{type} eq $Actions::SET_ACCESS_DURATION } @{$self->value->{actions}};
    if (scalar @actions > 0) {
        @actions = grep { $_->{type} eq $Actions::SET_UNREG_DATE } @{$self->value->{actions}};
        if (scalar @actions > 0) {
            $self->field('actions')->add_error("You can't define an access duration and a unregistration date at the same time.");
        }
    }
    else {
        @actions = grep { $_->{type} eq $Actions::SET_UNREG_DATE || $_->{type} eq $Actions::SET_ROLE }
          @{$self->value->{actions}};
        if (scalar @actions == 0) {
            $self->field('actions')->add_error("The actions must at least define a role, an access duration, or an unregistration date.");
        }
    }
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
