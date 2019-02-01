#!/usr/bin/perl

=head1 NAME

util

=head1 DESCRIPTION

unit test for pf::config::util

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

use pf::config::util;
use pf::file_paths qw($html_dir);
use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
{
    my $options = {};
    pf::config::util::add_standard_include_path($options);
    is_deeply(
        $options->{INCLUDE_PATH},
        [
            "$html_dir/captive-portal/profile-templates/default/emails",
            "$html_dir/captive-portal/templates/emails/"
        ],
        "Add standard paths when none are given"
    );
}

{
    my $options = {
        INCLUDE_PATH => "$html_dir/captive-portal/profile-templates/bob"
    };
    pf::config::util::add_standard_include_path($options);
    is_deeply(
        $options->{INCLUDE_PATH},
        [
            "$html_dir/captive-portal/profile-templates/bob",
            "$html_dir/captive-portal/profile-templates/default/emails",
            "$html_dir/captive-portal/templates/emails/"
        ],
        "Listify an single include",
    );
}

{
    my $options = {
        INCLUDE_PATH => [
            "$html_dir/captive-portal/profile-templates/bob1",
            "$html_dir/captive-portal/profile-templates/bob2",
        ],
    };
    pf::config::util::add_standard_include_path($options);
    is_deeply(
        $options->{INCLUDE_PATH},
        [
            "$html_dir/captive-portal/profile-templates/bob1",
            "$html_dir/captive-portal/profile-templates/bob2",
            "$html_dir/captive-portal/profile-templates/default/emails",
            "$html_dir/captive-portal/templates/emails/"
        ],
        "Add to an array",
    );
}

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

