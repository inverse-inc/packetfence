package pfappserver::Form::Config::PortalModule::Authentication::Password;

=head1 NAME

pfappserver::Form::Config::PortalModule::Authentcation::Password

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule::Authentication';
with 'pfappserver::Base::Form::Role::Help';

use captiveportal::DynamicRouting::Module::Authentication::Password;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::Authentication::Password'}

## Definition

has_field 'username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   tags => { after_element => \&help,
             help => 'Defines the username used for all authentications' },
  );

=head2 auth_module_definition

Overriding to remove the username

=cut

sub auth_module_definition {
    my ($self) = @_;
    return (qw(username));
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
