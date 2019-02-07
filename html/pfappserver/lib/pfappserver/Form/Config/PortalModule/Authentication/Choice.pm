package pfappserver::Form::Config::PortalModule::Authentication::Choice;

=head1 NAME

pfappserver::Form::Config::PortalModule::Authentcation::Choice

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule::Choice';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::MultiSource';
with 'pfappserver::Base::Form::Role::WithSource';
with 'pfappserver::Base::Form::Role::WithCustomFields';

use captiveportal::DynamicRouting::Module::Authentication::Choice;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::Authentication::Choice'}

## Definition

sub child_definition {
    my ($self) = @_;
    return ($self->source_fields, qw(custom_fields template));
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
