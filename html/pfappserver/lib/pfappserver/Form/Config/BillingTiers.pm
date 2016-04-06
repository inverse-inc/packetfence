package pfappserver::Form::Config::BillingTiers;

=head1 NAME

pfappserver::Form::Config::BillingTiers - Web form for a billing tier

=head1 DESCRIPTION

Form definition to create or update billing tiers.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;

has roles => ( is => 'rw' );

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Billing tier',
   required => 1,
   messages => { required => 'Please specify a billing tier identifier' },
  );

has_field 'name' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   tags => { after_element => \&help,
             help => 'The short name of the billing tier' },
  );

has_field 'description' =>
  (
   type => 'TextArea',
   label => 'Description',
   required => 1,
   tags => { after_element => \&help,
             help => 'A description of the billing tier' },
  );

has_field 'price' =>
  (
   type => 'Money',
   label => 'Price',
   required => 1,
   tags => { after_element => \&help,
             help => 'The price that will be charged to the customer' },
  );

  
has_field 'role' =>
  (
   type => 'Select',
   label => 'Role',
   options_method => \&options_roles,
   required => 1,
   tags => { after_element => \&help,
             help => 'The target role of the devices that use this tier.' },
  );

has_field 'access_duration' => (
   type => 'Duration',
   required => 1,
   tags => { after_element => \&help,
             help => 'The access duration of the devices that use this tier.' },
);

has_field 'use_time_balance' => (
    type             => 'Checkbox',
    label            => 'Use time balance',
    checkbox_value   => 'enabled',
    input_without_param   => 'disabled',
    tags             => { 
        after_element   => \&help,
        help            => 'Check this box to have the access duration be a real time usage.<br/>This requires a working accounting configuration.',
    },
);

=head2 options_roles

The list of roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my ($status, $roles) = $c->model('Roles')->list();
    return $self->SUPER::ACCEPT_CONTEXT($c, roles => $roles, @args);
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

