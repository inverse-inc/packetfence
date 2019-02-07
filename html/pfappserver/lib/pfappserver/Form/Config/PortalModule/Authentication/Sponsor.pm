package pfappserver::Form::Config::PortalModule::Authentication::Sponsor;

=head1 NAME

pfappserver::Form::Config::PortalModule::Authentcation::Sponsor

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule::Authentication';
with 'pfappserver::Base::Form::Role::Help';

use captiveportal::DynamicRouting::Module::Authentication::Sponsor;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::Authentication::Sponsor'}

## Definition

has_field 'forced_sponsor' =>
  (
   type => 'Text',
   label => 'Forced Sponsor',
   tags => { after_element => \&help,
             help => 'Defines the sponsor email used. Leave empty so that the user has to specify a sponsor.' },
  );

=head2 auth_module_definition

Overriding to add the forced sponsor option

=cut

sub auth_module_definition {
    my ($self) = @_;
    return (qw(forced_sponsor));
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
