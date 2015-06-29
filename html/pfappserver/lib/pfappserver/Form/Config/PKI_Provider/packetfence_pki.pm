package pfappserver::Form::Config::PKI_Provider::packetfence_pki;

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
   tags => { after_element => \&help,
             help => 'The unique id of the PKI provider'},
  );

has_field 'type' =>
  (
   type => 'Hidden',
   label => 'PKI Provider type',
   required => 1,
  );


has_field 'host' =>
  (
   type => 'Text',
   default => "127.0.0.1",
   tags => { after_element => \&help,
             help => 'Host which hosts the PacketFence PKI'},
  );

has_field 'port' =>
  (
   type => 'Text',
   default => '9393',
   tags => { after_element => \&help,
             help => 'Port on which to contact the PacketFence PKI API'},
  );

has_field 'proto' =>
  (
   type => 'Select',
   default => 'https',
   options => [{ label => 'https', value => 'https' }, { label => 'http' , value => 'http' }],
   tags => { after_element => \&help,
             help => 'Protocol to use to contact the PacketFence PKI API'},
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
   type => 'Country',
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
   type => 'Path',
   required => 1,
   tags => { after_element => \&help,
             help => 'Path of the CA that will generate your certificates'},
  );

has_field 'cn_attribute' =>
  (
   type => 'Select',
   label => 'Common name Attribute',
   options => [{ label => 'MAC address', value => 'mac' }, { label => 'Username' , value => 'pid' }],
   default => 'pid',
   tags => { after_element => \&help,
             help => 'Defines what attribute of the node to use as the common name during the certificate generation.' },
  );

has_field 'server_cert_path' =>
  (
   type => 'Path',
   required => 1,
   tags => { after_element => \&help,
             help => 'Path of the RADIUS server authentication certificate' },
  );

has_field 'revoke_on_unregistration' =>
  (
   type => 'Checkbox',
   label => 'Revoke on unregistration',
   checkbox_value => 'Y',
   tags => { after_element => \&help,
             help => 'Check this box to have the certificate revoke when the node using it is unregistered.<br/>Do not use if multiple devices share the same certificate.' },
  );



has_block definition =>
  (
    render_list => [qw(type proto host port username password profile country state organisation cn_attribute revoke_on_unregistration ca_cert_path server_cert_path)],
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
