package pfappserver::Form::Config::Authentication::Source::RADIUS;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::RADIUS - Web form for a Kerberos user source

=head1 DESCRIPTION

Form definition to create or update a RADIUS user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';
with 'pfappserver::Base::Form::Role::Help';

# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   element_class => ['input-small'],
   element_attr => {'placeholder' => '127.0.0.1'},
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port',
   element_class => ['input-mini'],
   element_attr => {'placeholder' => '1812'},
  );
has_field 'secret' =>
  (
   type => 'Password',
   label => 'Secret',
   required => 1,
  );
has_field 'stripped_user_name' =>
  (
   type            => 'Toggle',
   checkbox_value  => 'yes',
   unchecked_value => 'no',
   default         => 'yes',
   label           => 'Use stripped username ',
   tags => { after_element => \&help,
             help => 'Use stripped username returned by RADIUS to test the following rules.' },
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
