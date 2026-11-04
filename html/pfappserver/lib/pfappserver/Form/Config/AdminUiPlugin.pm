package pfappserver::Form::Config::AdminUiPlugin;

=head1 NAME

pfappserver::Form::Config::AdminUiPlugin - Web form for an admin UI plugin

=head1 DESCRIPTION

Form definition to create or update an admin UI plugin

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::constants::admin_roles qw(@ADMIN_ACTIONS);
use JSON::MaybeXS qw();

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Plugin',
   required => 1,
   apply => [
       {
           check   => qr/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/,
           message => 'The plugin identifier must only contain letters, digits, underscores and dashes',
       },
   ],
   messages => { required => 'Please specify the plugin identifier' },
  );

has_field 'enabled' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
  );

has_field 'description' =>
  (
   type => 'Text',
  );

has_field 'upstream' =>
  (
   type => 'Text',
   required => 1,
   apply => [
       {
           check   => qr{^https?://[^/\s]+(/\S*)?$},
           message => 'The upstream must be an http or https URL',
       },
   ],
   messages => { required => 'Please specify the base URL of the plugin API' },
  );

has_field 'manifest' =>
  (
   type => 'JSON',
  );

has_field 'acl' =>
  (
   type => 'Select',
   default => 'SYSTEM',
   options_method => \&options_acl,
  );

has_field 'replaces' =>
  (
   type => 'Text',
  );

has_field 'config_files' =>
  (
   type => 'Repeatable',
  );

has_field 'config_files.contains' =>
  (
   type => 'Text',
   apply => [
       {
           check   => qr/^[a-zA-Z0-9_.-]+\.conf:config::[a-zA-Z0-9_:]+$/,
           message => 'Each configuration file must be <file>.conf:<pfconfig namespace>, the file being in the configuration directory',
       },
   ],
  );

=head2 options_acl

The admin role action bases a plugin can require (SYSTEM for SYSTEM_READ, SYSTEM_UPDATE, ...)

=cut

sub options_acl {
    my %bases;
    for my $action (@ADMIN_ACTIONS) {
        next unless $action =~ /^(.+)_READ$/;
        $bases{$1} = 1;
    }
    return map { { value => $_, label => $_ } } sort keys %bases;
}

=head2 validate_manifest

The manifest, when given, must be a JSON object

=cut

sub validate_manifest {
    my ($self, $field) = @_;
    my $value = $field->value;
    return if !defined $value || $value eq '';
    my $manifest = eval { JSON::MaybeXS::decode_json($value) };
    if (ref($manifest) ne 'HASH') {
        $field->add_error('The manifest must be a JSON object');
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
