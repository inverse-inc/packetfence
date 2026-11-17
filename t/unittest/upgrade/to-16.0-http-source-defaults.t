#!/usr/bin/perl

=head1 NAME

to-16.0-http-source-defaults

=head1 DESCRIPTION

unit test for addons/upgrade/to-16.0-http-source-defaults.pl

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
require "$install_dir/addons/upgrade/to-16.0-http-source-defaults.pl";
use Test::More tests => 9;

#This test will running last
use Test::NoWarnings;

my $ini = pf::IniFiles->new(
    -file => "$install_dir/t/data/add-default-params/authentication.conf",
    -allowempty => 1,
);

my $updated;
{
    open(my $out, '>', \my $output);
    my $old = select($out);
    $updated = add_http_source_defaults($ini);
    select($old);
}

is($updated, 3, "the missing values of the HTTP sources are written");
is($ini->val('legacy_http', 'verify_tls'), 'disabled', "an existing HTTP source without verify_tls keeps not verifying TLS");
is($ini->val('checked_http', 'verify_tls'), 'enabled', "an HTTP source with verify_tls enabled keeps its value");
is($ini->val('json_http', 'verify_tls'), 'disabled', "an HTTP source with verify_tls disabled keeps its value");
is($ini->val('legacy_http', 'content_type'), 'application/x-www-form-urlencoded', "an existing HTTP source without content_type keeps sending a URL-encoded body");
is($ini->val('json_http', 'content_type'), 'application/json', "an HTTP source with content_type keeps its value");
ok(!$ini->exists('sql', 'verify_tls') && !$ini->exists('sql', 'content_type'), "the other sources are not changed");

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    $updated = add_http_source_defaults($ini);
    select($old);
}

is($updated, 0, "running it again changes nothing");

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
