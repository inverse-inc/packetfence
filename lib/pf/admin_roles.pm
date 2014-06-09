package pf::admin_roles;

=head1 NAME

pf::admin_roles add documentation

=cut

=head1 DESCRIPTION

pf::admin_roles

=cut

use strict;
use warnings;

use base qw(Exporter);
use pf::file_paths;
use List::MoreUtils qw(any all);
use pf::config::cached;

our @EXPORT = qw(admin_can admin_can_do_any admin_can_do_any_in_group @ADMIN_ACTIONS %ADMIN_ROLES $cached_adminroles_config);
our %ADMIN_ROLES;
our @ADMIN_ACTIONS = qw(
    SERVICES
    REPORTS
    USERS_READ
    USERS_CREATE
    USERS_UPDATE
    USERS_DELETE
    NODES_READ
    NODES_CREATE
    NODES_UPDATE
    NODES_DELETE
    CONFIGURATION_MAIN_READ
    CONFIGURATION_MAIN_UPDATE
    PORTAL_PROFILES_READ
    PORTAL_PROFILES_CREATE
    PORTAL_PROFILES_UPDATE
    PORTAL_PROFILES_DELETE
    MDM_READ
    MDM_CREATE
    MDM_UPDATE
    MDM_DELETE
    ADMIN_ROLES_READ
    ADMIN_ROLES_CREATE
    ADMIN_ROLES_UPDATE
    ADMIN_ROLES_DELETE
    INTERFACES_READ
    INTERFACES_CREATE
    INTERFACES_UPDATE
    INTERFACES_DELETE
    SWITCHES_READ
    SWITCHES_CREATE
    SWITCHES_UPDATE
    SWITCHES_DELETE
    FLOATING_DEVICES_READ
    FLOATING_DEVICES_CREATE
    FLOATING_DEVICES_UPDATE
    FLOATING_DEVICES_DELETE
    USERS_ROLES_READ
    USERS_ROLES_CREATE
    USERS_ROLES_UPDATE
    USERS_ROLES_DELETE
    USERS_SOURCES_READ
    USERS_SOURCES_CREATE
    USERS_SOURCES_UPDATE
    USERS_SOURCES_DELETE
    VIOLATIONS_READ
    VIOLATIONS_CREATE
    VIOLATIONS_UPDATE
    VIOLATIONS_DELETE
    SOH_READ
    SOH_CREATE
    SOH_UPDATE
    SOH_DELETE
    FINGERPRINTS_READ
    FINGERPRINTS_UPDATE
    USERAGENTS_READ
    MAC_READ
    MAC_UPDATE
    FIREWALL_SSO_READ
    FIREWALL_SSO_CREATE
    FIREWALL_SSO_UPDATE
    FIREWALL_SSO_DELETE
);


our %ADMIN_GROUP_ACTIONS = (
    CONFIGURATION_GROUP_READ => [
        qw( CONFIGURATION_MAIN_READ PORTAL_PROFILES_READ
          ADMIN_ROLES_READ  INTERFACES_READ SWITCHES_READ FLOATING_DEVICES_READ
          USERS_ROLES_READ  USERS_SOURCES_READ VIOLATIONS_READ SOH_READ
          FINGERPRINTS_READ USERAGENTS_READ MAC_READ)
      ],
    LOGIN_GROUP => [
        qw( SERVICES REPORTS USERS_READ NODES_READ CONFIGURATION_MAIN_READ
          PORTAL_PROFILES_READ MDM_READ ADMIN_ROLES_READ INTERFACES_READ
          SWITCHES_READ FLOATING_DEVICES_READ USERS_ROLES_READ USERS_SOURCES_READ
          VIOLATIONS_READ SOH_READ FINGERPRINTS_READ USERAGENTS_READ MAC_READ
          )
      ],
);

sub admin_can_do_any_in_group {
    my ($roles,$group) = @_;
    my $actions = $ADMIN_GROUP_ACTIONS{$group} if exists $ADMIN_GROUP_ACTIONS{$group};
    return ref $actions eq 'ARRAY' && admin_can_do_any($roles,@$actions);
}

sub admin_can {
    my ($roles, @actions) = @_;

    return 0 if any {$_ eq 'NONE'} @$roles;
    return any {
        my $role = $_;
        exists $ADMIN_ROLES{$role} && all { exists $ADMIN_ROLES{$role}{$_} } @actions
    } @$roles;
}

sub admin_can_do_any {
    my ($roles, @actions) = @_;

    return 0 if any {$_ eq 'NONE'} @$roles;
    return any {
        my $role = $_;
        exists $ADMIN_ROLES{$role} && any { exists $ADMIN_ROLES{$role}{$_} } @actions
    } @$roles;
}

sub reloadConfig {
    my ($config,$name) = @_;

    my %temp;
    $config->toHash(\%temp);
    $config->cleanupWhitespace(\%temp);
    %ADMIN_ROLES = ();
    while (my ($role,$data) = each %temp) {
        my $actions = $data->{actions} || '';
        my %action_data = map {$_ => undef} split /\s*,\s*/, $actions;
        $ADMIN_ROLES{$role} = \%action_data;
    }
    $ADMIN_ROLES{NONE} = {};
    $ADMIN_ROLES{ALL} = { map {$_ => undef} @ADMIN_ACTIONS };
    $config->cacheForData->set("ADMIN_ROLES", \%ADMIN_ROLES);
}

our $cached_adminroles_config = pf::config::cached->new(
    -file => $admin_roles_config_file,
    -allowempty => 1,
    -onfilereload => [
        file_reload_violation_config => \&reloadConfig
    ],
    -oncachereload => [
        cache_reload_violation_config => sub {
            my ($config,$name) = @_;
            my $data = $config->fromCacheForDataUntainted("ADMIN_ROLES");
            if ($data) {
                %ADMIN_ROLES = %$data;
            } else {
                $config->_callFileReloadCallbacks();
            }
        }
    ],
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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

