#!/usr/bin/perl

=head1 NAME

merged_list

=cut

=head1 DESCRIPTION

merged_list

=cut

use strict;
use warnings;
# pf core libs
my ($fh, $filename);

BEGIN {
    use lib qw(/usr/local/pf/t);
    use test_paths_serial;
    use setup_test_config;
    use File::Temp;
    ($fh, $filename) = File::Temp::tempfile( UNLINK => 1 );
    $pf::file_paths::pf_config_file = $filename;

    use pf::ConfigStore::Pf;
    pf::ConfigStore::Pf->new->commit;
}

use List::MoreUtils qw(any);
use Test::More tests => 6;
use Test::NoWarnings;
use Test::Exception;
use Test2::Tools::Compare qw();

use_ok('pf::config');

my @default_proxy_passthroughs = split /\s*,\s*/, $pf::config::Default_Config{fencing}{proxy_passthroughs};
# We use proxy_passthroughs to test the mergeable lists
my $val = $pf::config::Config{fencing}{proxy_passthroughs};
is_deeply($val, \@default_proxy_passthroughs , "Not overriden passthroughs are equal to the default ones.");

use_ok('pf::ConfigStore::Pf');

my @additionnal = (
    "www.dinde.ca",
    "www.zamm.it",
);

my $cs = pf::ConfigStore::Pf->new;
$cs->update('fencing', {'proxy_passthroughs' => join ',', @additionnal});
$cs->commit();
sleep(5);

Test2::Tools::Compare::isnt(
    $pf::config::Config{fencing}{proxy_passthroughs},
    \@default_proxy_passthroughs,
    "Merged passthroughs are not equal to the default ones."
);

is_deeply(
    $pf::config::Config{fencing}{proxy_passthroughs},
    [@default_proxy_passthroughs, @additionnal],
    "Merged passthroughs are actually merged"
);

$cs->update('fencing', {'proxy_passthroughs' => undef});
$cs->commit();

END {
    truncate $pf::file_paths::pf_config_file, 0;
    $cs->commit();
}

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

