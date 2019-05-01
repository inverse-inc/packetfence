#!/usr/bin/perl

=head1 NAME

api

=cut

=head1 DESCRIPTION

unit test for api

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

use Test::More tests => 8;
use utf8;

#This test will running last
use Test::NoWarnings;
use pf::I18N::api;

ok( pf::I18N::api->get_handle, "get_handle installed");

is(pf::I18N::api->localize("This is not localized"), "This is not localized", "localize text");

is(pf::I18N::api->localize("This is not localized with args [_1]", ['bob']), "This is not localized with args bob", "localize text with a placeholder");

is(pf::I18N::api->get_handle('en')->maketext("years"), "years", "Default localization");

is(pf::I18N::api->get_handle('fr')->maketext("years"), "années", "Localize french");

is_deeply(pf::I18N::api->languages_from_http_header('fr'), ['fr', 'i-default'], 'Extracting languages from header');

is_deeply(pf::I18N::api->languages_list(), {en => 'English', fr => 'French'}, "The lanaguage list from the filesystem");

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

