package pfappserver::Form::Interface::Create;

=head1 NAME

pfappserver::Form::Interface::Create - Web form to add a VLAN

=head1 DESCRIPTION

Form definition to add a VLAN to a network interface.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Interface';
with 'pfappserver::Base::Form::Role::Help';

# Form fields
has_field 'vlan' =>
  (
   type => 'PosInteger',
   label => 'Virtual LAN ID',
   required => 1,
   messages => { required => 'Please specify a VLAN ID.' },
   tags => { after_element => \&help,
             help => 'VLAN ID (must be a number bellow 4096)' },
  );

sub validate_vlan {
    my ( $self, $field ) = @_;
    my $field_value= $field->value;
    return ($field->add_error("Vlan Id should be between 0 - 4096")) if($field_value > 4095);
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
