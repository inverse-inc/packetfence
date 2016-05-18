package pfappserver::Form::Interface::CreateBond;

=head1 NAME

pfappserver::Form::Interface::CreateBond - Web form to add a Bond

=head1 DESCRIPTION

Form definition to add a Bond to the network configuration.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Interface';
with 'pfappserver::Base::Form::Role::Help';

has 'interfaces' => ( is => 'ro' );

# Form fields
has_field 'interface1' =>
  (
   type => 'Select',
   label => 'Interface 1',
   required => 1,
   option_method => \&options_interfaces,
   element_class => ['chzn-deselect'],
   element_attr => { 'data-placeholder' => 'None' },
   tags => { after_element => \&help,
             help => 'Select your first interface' },
  );

has_field 'interface2' =>
  (
   type => 'Select',
   label => 'Interface 2',
   required => 1,
   option_method => \&options_interfaces,
   element_class => ['chzn-deselect'],
   element_attr => { 'data-placeholder' => 'None' },
   tags => { after_element => \&help,
             help => 'Select your second interface' },
  );

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my ($status, $roles) = $c->model('Interface')->list();
    my @interfaces;
    return $self->SUPER::ACCEPT_CONTEXT($c, interfaces => @interfaces);
}

sub options_interfaces {
    my $self = shift;
    return $self->form->interfaces;
}

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
