#!/usr/bin/perl

=head1 NAME

filepermissions

=head1 DESCRIPTION

unit test for filepermissions

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::file_paths qw($captiveportal_profile_templates_path);
use Test::More tests => 2;
use pf::cmd::pf::fixpermissions;

#This test will running last
use Test::NoWarnings;
chmod(0777, $captiveportal_profile_templates_path);

pf::cmd::pf::fixpermissions->action_all();

my (
    $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
    $size, $atime, $mtime, $ctime, $blksize, $blocks
) = stat($captiveportal_profile_templates_path);

ok(($mode & 02775) == 02775, "$captiveportal_profile_templates_path permissions are fine");


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

