#!/usr/bin/perl

=head1 NAME

Template

=head1 DESCRIPTION

unit test for Template

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::util::template_switch;
use pf::config::builder::template_switches;
our @FILES;
our $SWITCH_DIR;
BEGIN {
    $SWITCH_DIR = '/usr/local/pf/lib/pf/Switch';
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @FILES = pf::util::template_switch::getDefFiles($SWITCH_DIR);
}

my $builder = pf::config::builder::template_switches->new;
use Test::More tests => (scalar @FILES) + 1;
#This test will running last
use Test::NoWarnings;
for my $file (@FILES) {
    my $name = pf::util::template_switch::fileNameToModuleName($SWITCH_DIR, $file);
    my $ini = pf::IniFiles->new( -file => $file, -fallback => $name);
    if (!defined $ini) {
        fail("load $file");
        next;
    }

    my ($error, undef) = $builder->build($ini);
    ok(!defined $error, "Building $file ");
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
