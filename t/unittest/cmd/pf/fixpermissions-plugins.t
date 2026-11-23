#!/usr/bin/perl

=head1 NAME

fixpermissions-plugins

=head1 DESCRIPTION

pfcmd fixpermissions file refuses the plugin descriptors (conf/plugins.d):
they stay root's

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
use File::Temp;
use pf::cmd::pf::fixpermissions;

# parse_file only accepts files under /usr/local/pf
my $base = File::Temp->newdir(DIR => '/usr/local/pf/t');
my $plugins_dir = "$base/plugins.d";
mkdir($plugins_dir) or die "$plugins_dir: $!";
sub touch {
    my ($file) = @_;
    open(my $fh, '>', $file) or die "$file: $!";
    close($fh);
    return $file;
}
my $descriptor = touch("$plugins_dir/acme.conf");
my $other = touch("$base/other.conf");
symlink($descriptor, "$base/link.conf") or die "symlink: $!";

local $pf::cmd::pf::fixpermissions::ui_plugins_conf_dir = $plugins_dir;
my $parse = sub {
    # parse_file prints why it refuses a file
    open(my $null, '>', '/dev/null') or die;
    local *STDERR = $null;
    return pf::cmd::pf::fixpermissions::parse_file(undef, @_);
};

is($parse->($descriptor), 0, "a plugin descriptor is refused");
is($parse->("$base//plugins.d/acme.conf"), 0, "another spelling of it (//) is refused");
is($parse->("$plugins_dir/../plugins.d/acme.conf"), 0, "another spelling of it (..) is refused");
is($parse->("$base/link.conf"), 0, "a symlink to it is refused");
is($parse->($other, $descriptor), 0, "the whole call is refused when one file is a descriptor");
is($parse->($other), 1, "a file outside the plugins directory is accepted");

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

