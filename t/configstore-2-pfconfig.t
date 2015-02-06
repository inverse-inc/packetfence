#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
#    use PfFilePaths;
#    use pf::log(service => 'pfconfig');
}

use Test::More;
#use Test::NoWarnings;
use Test::Deep;
use Config::IniFiles;
use pf::config::cached;
use Data::Dumper;
use Data::Compare;

use_ok('pfconfig::manager');
use_ok('pfconfig::cached_hash');

my %NewSwitchConfig;
tie %NewSwitchConfig, 'pfconfig::cached_hash', 'config::Switch';

use_ok('pf::ConfigStore::Switch');
#my $switch_cs = pf::ConfigStore::Switch->new;
#my $cs_ids = $switch_cs->readAllIds;

my %CSSwitchConfig = %pf::ConfigStore::Switch::SwitchConfig;


foreach my $key (keys %CSSwitchConfig){
  #my $cs_cfg = $switch_cs->read($key);
  print Dumper($NewSwitchConfig{$key}{inlineTrigger});
  print Dumper($CSSwitchConfig{$key}{inlineTrigger});
  my ($ok, $stack) = Test::Deep::cmp_details($NewSwitchConfig{$key}, $CSSwitchConfig{$key});
  ok($ok);
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

