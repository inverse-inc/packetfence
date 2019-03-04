package pfappserver::Form::Config::PortalModule::Root;

=head1 NAME

pfappserver::Form::Config::PortalModule:Root

=head1 DESCRIPTION

Form definition to create or update a root portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule::Chained';
with 'pfappserver::Base::Form::Role::Help';

use captiveportal::DynamicRouting::Module::Root;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::Root'}

## Definition

before 'setup' => sub {
    my ($self) = @_;
    $self->remove_field("actions");
};

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


