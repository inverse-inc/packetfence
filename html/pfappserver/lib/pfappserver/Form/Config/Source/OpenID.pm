package pfappserver::Form::Config::Source::OpenID;

=head1 NAME

pfappserver::Form::Config::Source::OpenID - Web form for a OpenID user source

=head1 DESCRIPTION

Form definition to create or update a OpenID user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::SourceLocalAccount';

use pf::Authentication::Source::OpenIDSource;

#Form fields
has_field 'client_id' =>
  (
   type => 'Text',
   label => 'App ID',
   required => 1,
   default => "",
  );
has_field 'client_secret' =>
  (
   type => 'Text',
   label => 'App Secret',
   required => 1,
   default => "",
  );
has_field 'site' =>
  (
   type => 'Text',
   label => 'API URL',
   required => 1,
   default => "",
   element_class => ['input-xlarge'],
  );
has_field 'access_token_path' =>
  (
   type => 'Text',
   label => 'API Token Path',
   required => 1,
   default => "",
  );
has_field 'authorize_path' =>
  (
   type => 'Text',
   label => 'API Authorize Path',
   required => 1,
   default => "",
  );
has_field 'scope' =>
  (
   utype => 'Text',
   label => 'Scope',
   required => 1,
   default => pf::Authentication::Source::OpenIDSource->meta->get_attribute('scope')->default,
   tags => { after_element => \&help,
             help => 'The permissions the application requests.' },
  );
has_field 'protected_resource_url' =>
  (
   type => 'Text',
   label => 'API URL of logged user',
   required => 1,
   default => "",
   element_class => ['input-xlarge'],
  );
has_field 'redirect_url' =>
  (
   type => 'Text',
   label => 'Portal URL',
   required => 1,
   default => pf::Authentication::Source::OpenIDSource->meta->get_attribute('redirect_url')->default,
   element_attr => {'placeholder' => pf::Authentication::Source::OpenIDSource->meta->get_attribute('redirect_url')->default},
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'The hostname must match your hostname and domain parameters set in System Configuration > Main Configuration > General Configuration.' },
  );

has_field 'domains' =>
  (
   type => 'Text',
   label => 'Authorized domains',
   required => 1,
   default => "",
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'Comma-separated list of domains that will be resolved with the correct IP addresses.' },
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
