package pfappserver::Form::ConfigStore::Provisioning::sepm;

=head1 NAME

pfappserver::Form::ConfigStore::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::ConfigStore::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'client_id' =>
  (
   type => 'Text',
   label => 'Client Id',
   required => 1,
  );

has_field 'client_secret' =>
  (
   type => 'Text',
   label => 'Client Secret',
   required => 1,
  );

has_field 'host' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'port' =>
  (
   type => 'PosInteger',
   required => 1,
  );

has_field 'protocol' =>
  (
   type => 'Select',
   options => [{ label => 'http', value => 'http' }, { label => 'https' , value => 'http' }],
  );

has_field 'access_token' =>
  (
   type => 'Text',
  );

has_block definition =>
  (
   render_list => [ qw(id type description client_id client_secret host port protocol access_token) ],
  );

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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
