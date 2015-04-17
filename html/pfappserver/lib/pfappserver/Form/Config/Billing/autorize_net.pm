package pfappserver::Form::Config::Billing::authorize_net;

=head1 NAME
pfappserver::Form::Config::Billing::authorize_net - Web form to add a Authorize.net configuration
=head1 DESCRIPTION
Form definition to create or update a Authorize.net configuration
=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Billing';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);


has_field 'authorizenet_posturl' =>
  (
   type => 'Text',
   label => 'URL Authorize.net',
   required => 1,
   messages => { required => 'Authorize.net URL gateway' },
   default => 'https://test.authorize.net/gateway/transact.dll',
  );

has_field 'authorizenet_login' =>
  (
   type => 'Text',
   label => 'Authorize.net API Login ID',
   required => 1,
   messages => { required => 'The merchant\'s unique API Login ID (Provided by Authorize.net)' },
  );

has_field 'authorizenet_trankey' =>
  (
   type => 'Text',
   label => 'Authorize.net Transaction Key',
   required => 1,
   messages => { required => 'The merchant\'s unique Transaction Key (Provided by Authorize.net)' },
  );


has_block definition =>
  (
   render_list => [ qw(id authorizenet_posturl authorizenet_login authorizenet_trankey) ],
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
