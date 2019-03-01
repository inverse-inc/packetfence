package pfappserver::Form::Config::PKI_Provider::scep;

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
   apply => [ pfappserver::Base::Form::id_validator('PKI provider name') ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   required => 1,
  );

has_field 'url' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'The url used to connect to the SCEP PKI service'},
  );

has_field 'username' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Username to connect to the SCEP PKI Service'},
  );

has_field 'password' =>
  (
   type => 'ObfuscatedText',
   tags => { after_element => \&help,
             help => 'Password for the username filled in above'},
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

has_field 'locality' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Locality for the certificate'},
  );

has_field 'organization' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Organization for the certificate'},
  );

has_field 'organizational_unit' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Organizational unit for the certificate'},
  );

has_field 'ca_cert_path' =>
  (
   type => 'Path',
   required => 1,
   tags => { after_element => \&help,
             help => 'Path of the CA that will generate your certificates'},
  );

has_field 'server_cert_path' =>
  (
   type => 'Path',
   required => 1,
   tags => { after_element => \&help,
             help => 'Path of the RADIUS server authentication certificate' },
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

has_field 'cn_format' => (
    type    => 'Text',
    label   => 'Common Name Format',
    default => '%s',
    tags    => {
        after_element   => \&help,
        help            => 'Defines how the common name will be formated. %s will expand to the defined Common Name Attribute value',
    },
);

has_block definition =>
  (
    render_list => [qw(type url username password country state locality organization organizational_unit cn_attribute cn_format ca_cert_path server_cert_path)],
  );

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
