#!/usr/bin/perl
=head1 NAME

chi_stats add documentation

=cut

=head1 DESCRIPTION

chi_stats

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

use pf::IniFiles;
use pf::file_paths;
use Benchmark;
use pf::config::cached;

timethese (-5, {
        'pf::IniFiles loading configurations from the filesystem' => sub {
            my $config = pf::IniFiles->new( -file => $pf_config_file, -import => pf::IniFiles->new( -file => $default_config_file));
        },
        'pf::config::cached loading configurations from the cache' => sub {
            my $config = pf::config::cached->new( -file => $pf_config_file,  -import => pf::config::cached->new( -file => $default_config_file));
        }
});

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

