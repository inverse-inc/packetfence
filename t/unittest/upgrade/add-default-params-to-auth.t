#!/usr/bin/perl

=head1 NAME

add-default-params-to-auth

=head1 DESCRIPTION

unit test for addons/upgrade/add-default-params-to-auth.pl

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
use pf::IniFiles;
require "$install_dir/addons/upgrade/add-default-params-to-auth.pl";
use Test::More tests => 6;

#This test will running last
use Test::NoWarnings;

my $ini = pf::IniFiles->new(
    -file => "$install_dir/t/data/add-default-params/authentication.conf",
    -allowempty => 1,
);

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    add_default_params($ini, 0);
    select($old);
}

is($ini->val('legacy_http', 'verify_tls'), 'disabled', "an HTTP source without verify_tls gets the default");
is($ini->val('checked_http', 'verify_tls'), 'enabled', "an HTTP source with verify_tls keeps its value");
is($ini->val('legacy_http', 'content_type'), 'application/x-www-form-urlencoded', "the other attributes get their default");
is($ini->val('legacy_http', 'host'), 'api.example.com', "the existing values are kept");

{
    my $dry = pf::IniFiles->new(
        -file => "$install_dir/t/data/add-default-params/authentication.conf",
        -allowempty => 1,
    );
    open(my $out, '>', \my $output);
    my $old = select($out);
    add_default_params($dry, 1);
    select($old);
    ok(!$dry->exists('legacy_http', 'verify_tls'), "a dry run changes nothing");
}

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
