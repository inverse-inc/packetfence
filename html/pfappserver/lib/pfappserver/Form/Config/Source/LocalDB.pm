package pfappserver::Form::Config::Source::LocalDB;

=head1 NAME

pfappserver::Form::Config::Source::LocalDB

=cut

=head1 DESCRIPTION

Form definition to create or update a LocalDB authentication source.

=cut

BEGIN {
    use pf::Authentication::Source::LocalDBSource;
}
use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

our $META = pf::Authentication::Source::LocalDBSource->meta;

# Form fields
has_field 'fallback_to_static_user_attributes' =>
  (
   type => 'Toggle',
   checkbox_value => '1',
   unchecked_value => '0',
   default => $META->get_attribute('fallback_to_static_user_attributes')->default,
   tags => { after_element => \&help,
             help => 'Assign the static attributes stored on the user itself when no rule of this '
                   . 'source matches. Those are the actions stored on the user, under '
                   . 'Users -> (user) -> Actions. When disabled, only the actions configured in '
                   . 'this source apply - administrator lockout possible. While enabled, rules can '
                   . 'only grant rights on top of the static attributes, they cannot revoke them.' },
  );

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

1;
