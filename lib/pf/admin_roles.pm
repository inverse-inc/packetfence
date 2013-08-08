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

our @EXPORT = qw(admin_can @ADMIN_ACTIONS %ADMIN_ROLES $cached_adminroles_config);
our %ADMIN_ROLES;
our @ADMIN_ACTIONS = qw(
    SERVICES
    REPORTS
    USERS_VIEW
    USERS_ADD
    USERS_MODIFY
    USERS_REMOVE
    NODES_VIEW
    NODES_ADD
    NODES_MODIFY
    NODES_REMOVE
    VIOLATIONS_VIEW
    VIOLATIONS_ADD
    VIOLATIONS_MODIFY
    VIOLATIONS_REMOVE
);

sub admin_can {
    my ($roles,@actions) = @_;
    return 0 if any {$_ eq 'NONE'} @$roles;
    return any { my $role = $_; exists $ADMIN_ROLES{$role} && all {exists $ADMIN_ROLES{$role}{$_} } @actions } @$roles;
}

sub reloadConfig {
    my ($config,$name) = @_;
    my %temp;
    $config->toHash(\%temp);
    $config->cleanupWhitespace(\%temp);
    %ADMIN_ROLES = ();
    while(my ($role,$data) = each %temp) {
        my $actions = $data->{actions} || '';
        my %action_data = map {$_ => undef} split /\s*,\s*/,$actions;
        $ADMIN_ROLES{$role} = \%action_data;
    }
    $ADMIN_ROLES{NONE} = {};
    $ADMIN_ROLES{ALL} = { map {$_ => undef} @ADMIN_ACTIONS };
    $config->cache->set("ADMIN_ROLES",\%ADMIN_ROLES);
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
            my $data = $config->cache->get("ADMIN_ROLES");
            if($data) {
                %ADMIN_ROLES = %$data;
            } else {
                reloadConfig($config,$name);
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

