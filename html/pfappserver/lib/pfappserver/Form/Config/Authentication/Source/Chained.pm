package pfappserver::Form::Config::Authentication::Source::Chained;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::Chained - Web form for a Chained user source

=cut

=head1 DESCRIPTION

pfappserver::Form::Config::Authentication::Source::Chained

Form definition to create or update a Chained user source.

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';
use pf::authentication;

# Form fields
has_field 'chained_authentication_source' =>
  (
   type => 'Select',
   options_method => \&options_chained_authentication_source,
  );

has_field 'authentication_source' =>
  (
   type => 'Select',
   options_method => \&options_authentication_source,
  );

our %ALLOWED_CHAINED_SOURCES = (
    SMS          => undef,
    Email        => undef,
    SponsorEmail => undef,
);

=head2 options_chained_authentication_source

Get the available chained authentication source options

=cut

sub options_chained_authentication_source {
    my ($self) = @_;
    return map_sources_to_options( grep { exists $ALLOWED_CHAINED_SOURCES{$_->type} }  @{pf::authentication::getExternalAuthenticationSources()} );
}

=head2 options_authentication_source

Get the available authentication source options

=cut

sub options_authentication_source {
    my ($self) = @_;
    return map_sources_to_options( grep { $_->type ne 'Chained' } @{pf::authentication::getInternalAuthenticationSources()} );
}

=head2 map_sources_to_options

Map the list of sources to options

=cut

sub map_sources_to_options {
    return map { { value => $_->id, label => $_->id, attributes => { 'data-source-class' => $_->class  } } } @_;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

