package pfappserver::Form::Config::PKI_Provider;

=head1 NAME

pfappserver::Form::Config::PKI_Provider

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;

use pf::factory::pki_provider;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'PKI Provider Name',
   required => 1,
   messages => { required => 'Please specify the name of the PKI provider' },
  );

has_field 'type' =>
  (
   type => 'Select',
   required => 1,
   messages => { required => 'PKI provider type is required.' },
   options => [map { { label => $_, value => $_ } } qw(inverse) ],
  );

has_field 'uri' =>
  (
   type => 'Text',
  );

has_field 'username' =>
  (
   type => 'Text',
  );

has_field 'password' =>
  (
   type => 'Password',
   password => 0,
  );

has_field 'profile' =>
  (
   type => 'Text',
  );

has_field 'country' =>
  (
   type => 'Text',
  );

has_field 'state' =>
  (
   type => 'Text',
  );

has_field 'organisation' =>
  (
   type => 'Text',
  );

has_block definition=>
  (
    render_list => [qw(type uri username password profile country state organisation)],
  );

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
