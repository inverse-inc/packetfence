package pfappserver::Form::ConfigStore::Provisioning;

=head1 NAME

pfappserver::Form::ConfigStore::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
#with 'pfappserver::Base::Form::Role::Help';

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'MDM ID',
   required => 1,
   messages => { required => 'Please specify the ID of the Provisioning entry.' },
  );
has_field 'description' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'Please specify the Description Provisioning entry.' },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'MDM type',
   required => 1,
   messages => { required => 'Please select MDM type' },
  );

has_field 'username' =>
  (
   type => 'Text',
   label => 'User name',
   required => 1,
   messages => { required => 'Username Required' },
  );

has_field 'password' =>
  (
   type => 'Password',
   label => 'Password',
   password => 0,
   required => 1,
   messages => { required => 'Password required' },
  );

has_field 'uri' =>
  (
   type => 'Text',
   label => 'Uri',
   required => 1,
   messages => { required => 'Uri required' },
  );

has_block definition =>
  (
   render_list => [ qw(id description type username password uri) ],
  );

sub options_type {
    return ({ label => 'Tem', value => 'tem'  } , { label => 'Symantec', value => 'symantec'});
}

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
