package pfappserver::Form::Config::PortalModule::Authentication::OAuth;

=head1 NAME

pfappserver::Form::Config::PortalModule::Authentcation::OAuth

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule::Authentication';

use captiveportal::DynamicRouting::Module::Authentication::OAuth;
sub for_module {'captiveportal::DynamicRouting::Module::Authentication::OAuth'}

has_field '+signup_template' => ( required => 0 );

# overriding to remove the signup template and custom fields
sub child_definition {
    my ($self) = @_;
    return (qw(source_id with_aup));
}

## Definition

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
