#!/usr/bin/perl
#
=head1 NAME

pf-switchfactory-preload -

=cut

=head1 DESCRIPTION

pf-switchfactory-preload

=cut

use strict;
use warnings;
use Benchmark qw(timethese);
use Module::Load;

use lib qw(/usr/local/pf/lib);

BEGIN {
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use pf::file_paths;
    my $test_dir ||= catdir($install_dir,'t');
    $pf::file_paths::switches_config_file = catfile($test_dir,'data/all-switch-types.conf');
    use pf::SwitchFactory;
}
use pfconfig::manager;
pfconfig::manager->new->expire_all;
pf::SwitchFactory->preloadConfiguredModules() if $ARGV[0];

my @SWITCHES = (keys %pf::SwitchFactory::SwitchConfig);

timethese(
    1,
    {   "Preloaded" => sub {
            foreach my $key (@SWITCHES) {
                my $switch = pf::SwitchFactory->instantiate($key);
            }
          },
    }
);

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

