package pf::Authentication::constants;

=head1 NAME

pf::Authentication::constants - Constants for authentication sources

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut

use strict;
use warnings;

use Readonly;

=head1 Conditions

Constants related to conditions rules.

=over

=cut

package Conditions;

=item STRING, NUMBER, DATE, TIME

Datatypes of conditions attributes (rules of authentication sources)

=cut

Readonly::Scalar our $STRING => 'string';
Readonly::Scalar our $NUMBER => 'number';
Readonly::Scalar our $DATE => 'date';
Readonly::Scalar our $TIME => 'time';

=item OPERATORS

Allowed operators for each attribute datatype

=cut

Readonly::Hash our %OPERATORS =>
  (
   $STRING => ['starts', 'equals', 'contains', 'ends'],
   $NUMBER => ['lower', 'lower or equals', 'equals', 'higher', 'higher or equals'],
   $DATE => ['is before', 'is', 'is after'],
   $TIME => ['is before', 'is after'],
  );

=back

=head1 Actions

Constants related to actions rules.

=over

=cut

package Actions;

=item MARK_AS_SPONSORS, SET_ACCESS_LEVEL, SET_ROLE, SET_UNREG_DATE

Available actions

=cut

Readonly::Scalar our $MARK_AS_SPONSOR => "mark_as_sponsor";
Readonly::Scalar our $SET_ACCESS_LEVEL => "set_access_level";
Readonly::Scalar our $SET_ROLE => "set_role";
Readonly::Scalar our $SET_UNREG_DATE => "set_unreg_date";

=item ACTIONS

List of available actions

=cut

Readonly::Array our @ACTIONS =>
  (
   $MARK_AS_SPONSOR,
   $SET_ACCESS_LEVEL,
   $SET_ROLE,
   $SET_UNREG_DATE,
  );

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
