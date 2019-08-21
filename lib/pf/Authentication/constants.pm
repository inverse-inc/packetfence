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
use pf::constants qw($TRUE $FALSE);

use base qw(Exporter);
our @EXPORT_OK = qw($LOCAL_ACCOUNT_UNLIMITED_LOGINS $LOGIN_SUCCESS $LOGIN_FAILURE $LOGIN_CHALLENGE $DEFAULT_LDAP_READ_TIMEOUT $DEFAULT_LDAP_WRITE_TIMEOUT $DEFAULT_LDAP_CONNECTION_TIMEOUT $HASH_PASSWORDS_DEFAULT);

Readonly::Scalar our $LOCAL_ACCOUNT_UNLIMITED_LOGINS => "0";
Readonly::Scalar our $LOGIN_SUCCESS => $TRUE;
Readonly::Scalar our $LOGIN_FAILURE => $FALSE;
Readonly::Scalar our $LOGIN_CHALLENGE => 2;
Readonly::Scalar our $DEFAULT_LDAP_READ_TIMEOUT => 10;
Readonly::Scalar our $DEFAULT_LDAP_WRITE_TIMEOUT => 5;
Readonly::Scalar our $DEFAULT_LDAP_CONNECTION_TIMEOUT => 1;
Readonly::Scalar our $HASH_PASSWORDS_DEFAULT => 'bcrypt';


=head1 Rules

General constants related to rules.

=cut

package Rules;

Readonly::Scalar our $ANY => 'any';
Readonly::Scalar our $ALL => 'all';

=over

=item AUTH, ADMIN

Available classes for a rule

=cut

Readonly::Scalar our $AUTH => 'authentication';
Readonly::Scalar our $ADMIN => 'administration';

=item CLASSES

List of available classes

=cut

Readonly::Array our @CLASSES => (
    $AUTH,
    $ADMIN,
);
Readonly::Hash our %CLASSES => map { $_ => 1 } @Rules::CLASSES;


=back

=head1 Conditions

Constants related to conditions rules.

=over

=cut

package Conditions;

Readonly::Scalar our $EQUALS => 'equals';
Readonly::Scalar our $NOT_EQUALS => 'not equals';
Readonly::Scalar our $CONTAINS => 'contains';
Readonly::Scalar our $STARTS => 'starts';
Readonly::Scalar our $ENDS => 'ends';
Readonly::Scalar our $MATCHES => 'matches regexp';
Readonly::Scalar our $LOWER => 'lower';
Readonly::Scalar our $LOWER_OR_EQUALS => 'lower or equals';
Readonly::Scalar our $HIGHER => 'higher';
Readonly::Scalar our $HIGHER_OR_EQUALS => 'higher or equals';
Readonly::Scalar our $IS_BEFORE => 'is before';
Readonly::Scalar our $IS => 'is';
Readonly::Scalar our $IN_TIME_PERIOD => 'in_time_period';
Readonly::Scalar our $IS_NOT => 'is not';
Readonly::Scalar our $IS_AFTER => 'is after';
Readonly::Scalar our $IS_MEMBER => 'is member of';

=item SUBSTRING, NUMBER, DATE, TIME

Datatypes of conditions attributes (rules of authentication sources)

=cut

Readonly::Scalar our $SUBSTRING => 'substring';
Readonly::Scalar our $NUMBER => 'number';
Readonly::Scalar our $DATE => 'date';
Readonly::Scalar our $TIME => 'time';
Readonly::Scalar our $TIME_PERIOD => 'time_period';
Readonly::Scalar our $CONNECTION => 'connection';
Readonly::Scalar our $LDAP_ATTRIBUTE => 'ldapattribute';

Readonly::Array our @TYPES => (
    $SUBSTRING,
    $NUMBER,
    $DATE,
    $TIME,
    $TIME_PERIOD,
    $CONNECTION,
    $LDAP_ATTRIBUTE,
);

=item OPERATORS

Allowed operators for each attribute datatype

=cut

Readonly::Hash our %OPERATORS =>
  (
   $SUBSTRING => [$STARTS, $EQUALS, $CONTAINS, $ENDS, $MATCHES],
   $NUMBER => [$LOWER, $LOWER_OR_EQUALS, $EQUALS, $HIGHER, $HIGHER_OR_EQUALS],
   $DATE => [$IS_BEFORE, $IS, $IS_AFTER],
   $TIME => [$IS_BEFORE, $IS_AFTER],
   $TIME_PERIOD => [$IN_TIME_PERIOD],
   $CONNECTION => [$IS, $IS_NOT],
   $LDAP_ATTRIBUTE => [$STARTS, $EQUALS, $NOT_EQUALS, $CONTAINS, $ENDS, $MATCHES, $IS_MEMBER],
  );

=back

=head1 Actions

Constants related to actions rules.

=over

=cut

package Actions;

=item MARK_AS_SPONSOR, SET_ACCESS_LEVEL, SET_ROLE, SET_ACCESS_DURATION, SET_ACCESS_DURATIONS, SET_UNREG_DATE SET_TIME_BALANCE, SET_BANDWIDTH_BALANCE

Available actions

=cut

Readonly::Scalar our $MARK_AS_SPONSOR => "mark_as_sponsor";
Readonly::Scalar our $SET_ACCESS_LEVEL => "set_access_level";
Readonly::Scalar our $SET_TENANT_ID => "set_tenant_id";
Readonly::Scalar our $SET_ROLE => "set_role";
Readonly::Scalar our $SET_ACCESS_DURATION => "set_access_duration";
Readonly::Scalar our $SET_ACCESS_DURATIONS => "set_access_durations";
Readonly::Scalar our $SET_UNREG_DATE => "set_unreg_date";
Readonly::Scalar our $SET_TIME_BALANCE => "set_time_balance";
Readonly::Scalar our $SET_BANDWIDTH_BALANCE => "set_bandwidth_balance";
=item ACTIONS

List of available actions

=cut

Readonly::Hash our %ACTIONS => (
    $Rules::AUTH    => [ $SET_ROLE, $SET_ACCESS_DURATION, $SET_UNREG_DATE, $SET_TIME_BALANCE, $SET_BANDWIDTH_BALANCE ],
    $Rules::ADMIN   => [ $SET_ACCESS_LEVEL, $MARK_AS_SPONSOR, $SET_TENANT_ID, $SET_ACCESS_DURATIONS ],
);

Readonly::Hash our %ACTION_CLASS_TO_TYPE => (
    $SET_ROLE               => $Rules::AUTH,
    $SET_UNREG_DATE         => $Rules::AUTH,
    $SET_ACCESS_DURATION    => $Rules::AUTH,
    $SET_TIME_BALANCE       => $Rules::AUTH,
    $SET_BANDWIDTH_BALANCE  => $Rules::AUTH,

    $SET_ACCESS_LEVEL       => $Rules::ADMIN,
    $SET_TENANT_ID          => $Rules::ADMIN,
    $MARK_AS_SPONSOR        => $Rules::ADMIN,
    $SET_ACCESS_DURATIONS   => $Rules::ADMIN,
);

Readonly::Hash our %ALLOWED_ACTIONS => (
    $MARK_AS_SPONSOR  => {$MARK_AS_SPONSOR  => 1},
    $SET_ACCESS_LEVEL => {$SET_ACCESS_LEVEL => 1},
    $SET_TENANT_ID    => {$SET_TENANT_ID => 1},
    $SET_ROLE         => {$SET_ROLE         => 1},
    $SET_UNREG_DATE   => {
        $SET_UNREG_DATE      => 1,
        $SET_ACCESS_DURATION => 1,
    },
    $SET_TIME_BALANCE => {$SET_TIME_BALANCE => 1},
    $SET_BANDWIDTH_BALANCE => {$SET_BANDWIDTH_BALANCE => 1},
    $SET_ACCESS_DURATIONS => {$SET_ACCESS_DURATIONS => 1},
);

Readonly::Hash our %MAPPED_ACTIONS => (
    $MARK_AS_SPONSOR        => $MARK_AS_SPONSOR,
    $SET_ACCESS_LEVEL       => $SET_ACCESS_LEVEL,
    $SET_TENANT_ID          => $SET_TENANT_ID,
    $SET_ROLE               => $SET_ROLE,
    $SET_UNREG_DATE         => $SET_UNREG_DATE,
    $SET_ACCESS_DURATION    => $SET_UNREG_DATE,
    $SET_ACCESS_DURATIONS   => $SET_ACCESS_DURATIONS,
);

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
