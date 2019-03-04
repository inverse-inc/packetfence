package pfappserver::Form::Config::PortalModule::SelectRole;

=head1 NAME

pfappserver::Form::Config::PortalModule:Choice

=head1 DESCRIPTION

Form definition to create or update a choice portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';

use pf::nodecategory;

use captiveportal::DynamicRouting::Module::SelectRole;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::SelectRole'}
## Definition

has_field 'admin_role' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Admin role',
   options_method => \&options_admin_role,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Which roles should have access to this module to select the role' },
  );

has_field 'template' =>
  (
   type => 'Text',
   label => 'Template',
   tags => { after_element => \&help,
             help => 'The template to use' },
  );

has_field 'list_role' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Role List',
   options_method => \&options_admin_role,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Which roles can be select' },
  );

sub child_definition {
    return qw(admin_role list_role template);
}

sub BUILD {
    my ($self) = @_;
    $self->field('template')->default($self->for_module->meta->find_attribute_by_name('template')->default->());
}

sub options_admin_role {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } nodecategory_view_all();
    return @roles;
}

=over

=back

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


