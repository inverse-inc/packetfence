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
   options_method => \&options_type,
  );

has_field 'uri' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Uri on which we should contact the PKI'},
  );

has_field 'username' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Username to connect to the PKI'},
  );

has_field 'password' =>
  (
   type => 'Password',
   password => 0,
   tags => { after_element => \&help,
             help => 'Password for the username filled in above'},
  );

has_field 'profile' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Profile used for the generation of certificate'},
  );

has_field 'country' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Country for the certificate'},
  );

has_field 'state' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'State for the certificate'},
  );

has_field 'organisation' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Organisation for the certificate'},
  );

has_field 'ca_cert_path' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Path of the CA that will generate your certificates'},
  );

has_field 'cn_attribute' =>
  (
   type => 'Select',
   options => [{ label => 'MAC address', value => 'mac' }, { label => 'Username' , value => 'pid' }],
   default => 'pid',
   tags => { after_element => \&help,
             help => 'Defines what attribute of the node to use as the common name during the certificate generation.' },
  );

has_field 'server_cert_path' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Path of the Radius Server Authentication certificate' },
  );

has_block definition=>
  (
    render_list => [qw(type uri username password profile country state organisation cn_attribute ca_cert_path server_cert_path)],
  );

=head2 options_type

Options for types

=cut

sub options_type {
    return map {
        { 'label' => "pf::pki_provider::${_}", value => $_}} @pf::factory::pki_provider::TYPES;
}

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
