#!/usr/bin/perl

=head1 NAME

benchmark_config

=head1 DESCRIPTION

Benchmark the configuration read

=cut

use strict;
use warnings;

use lib '/usr/local/fingerbank/lib';
use lib '/usr/local/pf/lib';
use fingerbank::Log;
use fingerbank::Config;
use fingerbank::NullCache;
require pf::fingerbank;

use Benchmark qw(:all);

fingerbank::Log->init_logger; 

my $null_cache = fingerbank::NullCache->new;
pf::fingerbank::cache()->clear();

timethese(20000, {
    'without cache' => sub {
        $fingerbank::Config::CACHE = $null_cache;
        fingerbank::Config::read_config();
    },
    'with cache' => sub {
        $fingerbank::Config::CACHE = pf::fingerbank::cache();
        fingerbank::Config::read_config();
    },
});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
