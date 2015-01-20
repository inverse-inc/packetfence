package pfappserver::Form::Config::Provisioning::eap;

=head1 NAME

pfappserver::Form::Config::eap - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning::mobileconfig';
with 'pfappserver::Base::Form::Role::Help';

has_field '+company' =>
  (
   required => 0,
  );

has_field '+reversedns' =>
  (
   required => 0,
  );

has_field 'pki' =>
  (
   type => 'Text',
   label => 'PKI URI',
   required => 1,
   tags => { after_element => \&help,
             help => 'Example: https://packetfence.org:8081/pki/api/' },
  );

has_field 'username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
  );

has_field 'password' =>
  (
   type => 'Text',
   label => 'Password',
   required => 1,
  );

has_field '+eap_type' =>
  (
   default => '13',
  );

has_field '+security_type' =>
  (
   default => 'WPA',
  );

has_block definition =>
  (
   render_list => [ qw(id type description category pki ssid security_type eap_type username password) ],
  );


=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
