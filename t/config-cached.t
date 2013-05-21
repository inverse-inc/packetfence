#!/usr/bin/perl
=head1 NAME

config-cached add documentation

=cut

=head1 DESCRIPTION

config-cached

=cut

use strict;
use warnings;
# pf core libs
use lib '/usr/local/pf/lib';
use Log::Log4perl;
use File::Path qw(remove_tree);

our (%DATA);

BEGIN {

Log::Log4perl->init("./log.conf");
    use pf::file_paths;
    $pf::file_paths::chi_config_file = './data/chi.conf';
}

use Test::More tests => 6;                      # last test to print

use Test::NoWarnings;

use_ok("pf::config::cached");

my $config =  pf::config::cached->new(
    -file => './data/test.conf',
    -onreload => [
        reload => sub {
            my ($config,$name) = @_;
            $config->toHash(\%DATA);
        }
    ],
);

isa_ok($config,"pf::config::cached");

isa_ok($config,"Config::IniFiles","Prending to be a Config::IniFiles");

ok(exists $DATA{section1},"section1 exists");

ok($DATA{section1}{param1} eq 'value1',"section1.param1 eq value1");

END {
    remove_tree('/tmp/chi');
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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


