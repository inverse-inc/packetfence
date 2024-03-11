package pfappserver::Form::Config::Cloud::Intune;

=head1 NAME

pfappserver::Form::Config::Cloud::Intune - Web form to add a Microsoft Intune service

=head1 DESCRIPTION

Form definition to create or update a Microsoft Intune service.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Cloud';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'tenant_id' =>
  (
   type => 'Text',
   label => 'Tenant ID',
   required => 1,
   messages => { required => 'Please specify the Tenant ID for the Intune Service' },
  );

has_field 'client_id' =>
  (
   type => 'Text',
   label => 'Client ID',
   required => 1,
   messages => { required => 'Please specify the Client ID for the Intune Service' },
  );

has_field 'client_secret' =>
  (
   type => 'ObfuscatedText',
   label => 'Client Secret',
   required => 1,
   messages => { required => 'Please specify the Tenant ID for the Intune Service' },
  );


has_field 'type' =>
  (
   type => 'Hidden',
   default => 'Intune',
  );

has_block definition =>
  (
   render_list => [ qw(id tenant_id client_id client_secret) ],
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
