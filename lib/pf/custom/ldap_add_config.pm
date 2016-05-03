package pf::custom::ldap_add_config;

=head1 NAME

pf::custom::ldap_add_config -

=cut

=head1 DESCRIPTION

pf::custom::ldap_add_config

=cut

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(%LdapAddConfig);

our %LdapAddConfig = (
    host         => '',
    port         => 389,
    encryption   => 'tls',
    user_ou      => 'OU=testaccount,DC=inverse,DC=inc',
    binddn       => 'CN=Administrator,CN=Users,DC=inverse,DC=inc',
    user_groups  => ['CN=tsestgroup,OU=testaccount,DC=inverse,DC=inc'],
    objectClass  => ['top', 'person', 'organizationalPerson', 'user'],
    allowed_profiles => [qw(default)],
    password     => '',
    username_generation => {
        min => 6,
        max => 8,
    },
    password_generation => {
        min => 8,
        max => 10,
    },
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
