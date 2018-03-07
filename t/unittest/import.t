#!/usr/bin/perl

=head1 NAME

import

=cut

=head1 DESCRIPTION

unit test for import

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

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
use pf::import;
use File::Temp;

my $fh = File::Temp->new;

my $name = $fh->filename;

system("perl -T -I/usr/local/pf/t  -Msetup_test_config /usr/local/pf/bin/pfcmd.pl import nodes $name");

is($?, 0, "Succeeded running with an empty file");

for my $o (0..255) {
    print $fh sprintf("00:11:55:22:33:%02x,default\n", $o);
}

$fh->flush;

system("/usr/local/pf/bin/pfcmd import nodes $name columns=mac,pid");

is($?, 0, "Succeeded importing 00:11:55:22:33:00 - 00:11:55:22:33:ff with the default user");

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

