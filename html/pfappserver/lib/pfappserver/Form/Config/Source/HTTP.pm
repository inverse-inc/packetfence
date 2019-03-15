package pfappserver::Form::Config::Source::HTTP;

=head1 NAME

pfappserver::Form::Config::Source::HTTP - Web form for a HTTP user source

=head1 DESCRIPTION

Form definition to create or update a HTTP user source.

=cut

use HTML::FormHandler::Moose;
use pf::Authentication::Source::HTTPSource;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   element_class => ['input-small'],
   element_attr => {'placeholder' => pf::Authentication::Source::HTTPSource->meta->get_attribute('host')->default},
   default => pf::Authentication::Source::HTTPSource->meta->get_attribute('host')->default,
  );
has_field 'port' =>
  (
   type => 'Port',
   label => 'Port',
   element_class => ['input-mini'],
   element_attr => {'placeholder' => pf::Authentication::Source::HTTPSource->meta->get_attribute('port')->default},
   default => pf::Authentication::Source::HTTPSource->meta->get_attribute('port')->default,
  );

has_field 'protocol' =>
  (
   type => 'Select',
   label => 'Encryption',
   options => 
   [
    { value => 'http', label => 'http' },
    { value => 'https', label => 'https' },
   ],
   required => 1,
   element_class => ['input-small'],
   default => pf::Authentication::Source::HTTPSource->meta->get_attribute('protocol')->default,
  );
has_field 'username' =>
  (
   type => 'Text',
   label => 'API username (basic auth)',
  );
has_field 'password' =>
  (
   type => 'ObfuscatedText',
   label => 'API password (basic auth)',
   trim => undef,
  );
has_field 'authentication_url' =>
  (
   type => 'Text',
   label => 'Authentication URL',
   required => 1,
   tags => { after_element => \&help,
             help => 'Note : The URL is always prefixed by a slash (/)' },
  );
has_field 'authorization_url' =>
  (
   type => 'Text',
   label => 'Authorization URL',
   required => 1,
   tags => { after_element => \&help,
             help => 'Note : The URL is always prefixed by a slash (/)' },
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
