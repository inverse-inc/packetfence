package pfappserver::Form::Config::PortalModule::RoleInStone;

=head1 NAME

pfappserver::Form::Config::PortalModule:RoleInStone

=head1 DESCRIPTION

Form definition to create or update a Role in stone portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';

use pf::nodecategory;

use captiveportal::DynamicRouting::Module::RoleInStone;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::RoleInStone'}
## Definition

has_field 'stone_roles' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_admin_role,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will be affected' },
  );

sub child_definition {
    return qw(stone_roles);
}

sub options_admin_role {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } nodecategory_view_all();
    return @roles;
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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


