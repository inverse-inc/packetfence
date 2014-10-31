package pfappserver::Form::Config::Authentication::Source::Chained;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::Chained add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Config::Authentication::Source::Chained

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';
use pf::authentication;

# Form fields
has_field 'pre_authentication_source' =>
  (
   type => 'Select',
   options_method => \&options_sources,
  );

has_field 'authentication_source' =>
  (
   type => 'Select',
   options_method => \&options_sources,
  );

has_field 'use_rules_from_authentication_source' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );

=head2 options_sources

Returns the list of sources to be displayed

=cut

sub options_sources {
    return map { { value => $_->id, label => $_->id, attributes => { 'data-source-class' => $_->class  } } } @{getAllAuthenticationSources()};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

1;

