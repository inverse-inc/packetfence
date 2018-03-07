#!/usr/bin/perl

=head1 NAME

pfappserver

=cut

=head1 DESCRIPTION

unit test for pfappserver

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

use Test::More tests => 10;
use utf8;

#This test will running last
use Test::NoWarnings;
use pf::I18N::pfappserver;

ok( pf::I18N::pfappserver->get_handle, "get_handle installed");

is(pf::I18N::pfappserver->localize("This is not localized"), "This is not localized", "localize text");

is(pf::I18N::pfappserver->localize("This is not localized with args [_1]", ['bob']), "This is not localized with args bob", "localize text with a placeholder");

is(pf::I18N::pfappserver->localize("work_phone"), "work phone", "Localize english");

is(pf::I18N::pfappserver->get_handle('en')->maketext("work_phone"), "work phone", "Default localization");

is( pf::I18N::pfappserver->get_handle('es')->maketext("work_phone"), "work phone", "Default localization wrong lanaguage given");

is(pf::I18N::pfappserver->get_handle('fr')->maketext("work_phone"), "Téléphone de bureau", "Localize french");

is_deeply(pf::I18N::pfappserver->languages_from_http_header('fr'), ['fr', 'i-default'], 'Extracting languages from header');

is_deeply(pf::I18N::pfappserver->languages_list(), {en => 'English', fr => 'French'}, "The lanaguage list from the filesystem");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

