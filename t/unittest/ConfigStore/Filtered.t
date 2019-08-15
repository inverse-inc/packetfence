#!/usr/bin/perl

=head1 NAME

Filtered

=head1 DESCRIPTION

unit test for Filtered

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

{
    package Filtered;
    use Moo;
    extends 'pf::ConfigStore';
    with 'pf::ConfigStore::Filtered';
    sub filterSection {
        $_[1] =~ /^\S+$/
    }
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;

#This is the first test
my $configStore = Filtered->new(configFile => '/usr/local/pf/t/data/test.conf');

is_deeply(
    $configStore->readAllIds(),
    [qw(default section1 section2)],
);

ok(!$configStore->hasId("section1 group 1"));

ok($configStore->hasId("section1"));

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
