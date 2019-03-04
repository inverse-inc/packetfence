package pfappserver::Form::Config::Source::Kerberos;

=head1 NAME

pfappserver::Form::Config::Source::Kerberos - Web form for a Kerberos user source

=head1 DESCRIPTION

Form definition to create or update a Kerberos user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   required => 1,
   # Default value needed for creating dummy source
   default => "",
   element_class => ['input-small'],
   element_attr => {'placeholder' => '127.0.0.1'},
  );
has_field 'authenticate_realm' =>
  (
   type => 'Text',
   label => 'Realm to use to authenticate',
   required => 1,
   # Default value needed for creating dummy source
   default => "",
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
