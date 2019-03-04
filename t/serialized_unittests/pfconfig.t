#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use test_paths_serial;
    use setup_test_config;
    `cp $pf::file_paths::switches_config_file $pf::file_paths::switches_config_file.tmp`;
    $pf::file_paths::switches_config_file = "$pf::file_paths::switches_config_file.tmp";

    use pfconfig::manager;
    my $manager = pfconfig::manager->new;
    $manager->expire('config::Switch');
    
    use pf::log;
}

END {
    `rm $pf::file_paths::switches_config_file`;
}

use Test::More;
use Test::Deep;
use Config::IniFiles;

my %default_cfg;
my %doc;

use_ok('pfconfig::manager');
use_ok('pfconfig::cached_hash');
use_ok('pfconfig::cached_array');

my %SwitchConfig;
tie %SwitchConfig, 'pfconfig::cached_hash', 'config::Switch';

my $manager = pfconfig::manager->new;

# switches conf config file
my %switches_conf_file;
tie %switches_conf_file, 'Config::IniFiles', ( -file => $pf::file_paths::switches_config_file );

#####
# Test resource expiration with resource dependencies

# we write the role of the default switch
my $new_role = "role#1";
$switches_conf_file{'default'}{'registrationRole'} = $new_role;
ok(tied(%switches_conf_file)->RewriteConfig, 'rewrote switches config file');

# we refresh the cache
$manager->expire('config::Switch');
my %switches = %{$manager->get_cache('config::Switch')};

# the role should be set in the default section and in the resource default_switch
my $role = $switches{default}{registrationRole};
ok(($role eq $new_role), "role is set in default switch in pfconfig config::Switch");

$role = $SwitchConfig{default}{registrationRole};
ok(($role eq $new_role), "role is set in default switch in pfconfig cached_hash");

my %default_switch = %{$manager->get_cache('resource::default_switch')};
$role = $default_switch{registrationRole};

ok(($role eq $new_role), "role is set in default switch in pfconfig resource::default_switch");

# we now change the configuration, write it and expire
$new_role = "changed it";
$switches_conf_file{'default'}{'registrationRole'} = $new_role;
ok(tied(%switches_conf_file)->RewriteConfig, 'rewrote switches config file');

$manager->expire('config::Switch');

# we now check that the role has changed in the default section and in the default_switch resource
%switches = %{$manager->get_cache('config::Switch')};
$role = $switches{default}{registrationRole};

ok(($role eq $new_role), "role is set in default switch in pfconfig config::Switch");

$role = $SwitchConfig{default}{registrationRole};
ok(($role eq $new_role), "role is set in default switch in pfconfig cached_hash");

%default_switch = %{$manager->get_cache('resource::default_switch')};
$role = $default_switch{registrationRole};

ok(($role eq $new_role), "role is changed in default switch in pfconfig resource::default_switch");

done_testing();

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
