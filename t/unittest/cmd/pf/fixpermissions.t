#!/usr/bin/perl

=head1 NAME

fixpermissions

=head1 DESCRIPTION

unit test for fixpermissions

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::cmd::pf::fixpermissions;
use pf::constants qw($CONF_FILE_MODE $SECRET_FILE_MODE);
use pf::file_paths qw($conf_dir $html_dir);

is($CONF_FILE_MODE & 07, 0, "configuration files are not readable by others");
is($SECRET_FILE_MODE & 07, 0, "secret files are not readable by others");
is(pf::cmd::pf::fixpermissions::_file_mode("$conf_dir/domain.conf"), $CONF_FILE_MODE, "file in the configuration directory");
is(pf::cmd::pf::fixpermissions::_file_mode("$html_dir/captive-portal/templates/layout.html"), 0664, "file outside the configuration directory");

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
