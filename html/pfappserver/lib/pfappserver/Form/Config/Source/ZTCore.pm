package pfappserver::Form::Config::Source::ZTCore;

=head1 NAME

pfappserver::Form::Config::Source::ZTCore - Web form for a ZTCore user source

=head1 DESCRIPTION

Form definition to create or update a ZTCore user source.

=cut

BEGIN {
    use pf::Authentication::Source::ZTCoreSource;
}

use pf::authentication;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::NoRules
);

our $META = pf::Authentication::Source::ZTCoreSource->meta;

# Form fields
has_field 'auth_base_url' =>
  (
   required => 1,
   default => $META->get_attribute('auth_base_url')->default,
  );

has_field 'assertion_url' =>
  (
   required => 1,
   default => $META->get_attribute('assertion_url')->default,
  );


has_field 'shared_secret' =>
  (
   required => 1,
  );


=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

