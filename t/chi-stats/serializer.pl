#!/usr/bin/perl
=head1 NAME

serializer add documentation

=cut

=head1 DESCRIPTION

serializer

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths;
use Benchmark qw(timethese cmpthese);
use CHI;

my $chi1 = CHI->new(
    driver => 'Memory',
    datastore => {},
    namespace => 'chistats1',
    serializer => 'Sereal',
#    compress_threshold => 1000,
);

my $chi2 = CHI->new(
    driver => 'Memory',
    datastore => {},
    namespace => 'chistats2',
#    compress_threshold => 1000,
);

#Preload the file in memory
my $config = pf::IniFiles->new( -file => $pf_config_file,  -import => pf::IniFiles->new( -file => $default_config_file));

my $results = timethese (1000, {
        '01 Using Sereal' => sub {
            $chi1->set("configfile", pf::IniFiles->new( -file => $pf_config_file,  -import => pf::IniFiles->new( -file => $default_config_file)) )  ;
            my $config = $chi1->get("configfile");
        },
        '00 Using Default' => sub {
            $chi2->set("configfile", pf::IniFiles->new( -file => $pf_config_file,  -import => pf::IniFiles->new( -file => $default_config_file)) )  ;
            my $config = $chi2->get("configfile");
        }
});

cmpthese($results);



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

