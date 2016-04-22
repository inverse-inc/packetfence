package pfappserver::Form::Config::Domain;

=head1 NAME

pfappserver::Form::Config::Domain - Web form for domains

=head1 DESCRIPTION

Form definition to create or update domains.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Identifier',
   required => 1,
   maxlength => 10,
   messages => { required => 'Please specify an identifier' },
   tags => { after_element => \&help,
             help => 'Specify a unique identifier for your configuration.<br/>This doesn\'t have to be related to your domain' },
   apply => [
       {   check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/,
           message =>
             'The domain id is invalid. A domain id can only contain alphanumeric characters, dashes, period and or underscores'
       }
   ],
  );

has_field 'workgroup' =>
  (
   type => 'Text',
   label => 'Workgroup',
   required => 1,
   messages => { required => 'Please specify the workgroup' },
  );

has_field 'ad_server' =>
  (
   type => 'Text',
   label => 'Active Directory server',
   required => 1,
   messages => { required => 'Please specify the Active Directory server' },
   tags => { after_element => \&help,
             help => 'The IP address or DNS name of your Active Directory server' },
  );

has_field 'bind_pass' =>
  (
   type => 'Password',
   label => 'Password',
   required => 1,
   messages => { required => 'Please specify the password to bind to the Active Directory' },
  );

has_field 'bind_dn' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   messages => { required => 'Please specify the user to bind to the Active Directory server' },

  );

has_field 'dns_server' =>
  (
   type => 'IPAddress',
   label => 'DNS server',
   required => 1,
   messages => { required => 'Please specify the DNS server' },
   tags => { after_element => \&help,
             help => 'The IP address of the DNS server for this domain.' },
  );

has_field 'server_name' =>
  (
   type => 'Text',
   label => 'This server\'s name',
   required => 1,
   maxlength => 14,
   messages => { required => 'Please specify the server\'s name' },
   tags => { after_element => \&help,
             help => 'This server\'s name (account name) in your Active Directory.' },
  );

has_field 'dns_name' =>
  (
   type => 'Text',
   label => 'DNS name of the domain',
   required => 1,
   messages => { required => 'Please specify the DNS name of the domain' },
   tags => { after_element => \&help,
             help => 'The DNS name (FQDN) of the domain.' },
  );

has_field 'registration' =>
  (
   type => 'Checkbox',
   label => 'Allow on registration',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the device will be able to reach the Active Directory from the registration VLAN.' },
  );

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
