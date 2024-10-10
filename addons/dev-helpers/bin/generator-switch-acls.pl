#!/usr/bin/perl

=head1 NAME

generator-switch-acls -

=head1 DESCRIPTION

generator-switch-acls

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::SwitchFactory;
use Data::Dumper;
use Template;
use pf::file_paths qw($install_dir);
use List::MoreUtils qw(any);
pf::SwitchFactory->preloadAllModules();
my %supportTypes = (
    AccessListBasedEnforcement => 1,
    DownloadableListBasedEnforcement => 1,
);

my @supports = grep { my $s = $_; any { exists $supportTypes{$_} } @{$_->{supports}} } map { @$_ } values %pf::SwitchFactory::VENDORS;

my %ACLsSupports;

for my $s (@supports) {
    for my $k (keys %supportTypes) {
        if (any { $_ eq $k } @{$s->{supports}}) {
            $ACLsSupports{$k}{$s->{value}} = 1;
        }
    }
}

my $tt = Template->new({
    OUTPUT_PATH  => "$install_dir/lib/pf/constants/",
    INCLUDE_PATH => "$install_dir/addons/dev-helpers/templates",
});

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Purity = 1;
$Data::Dumper::Terse = 0;
$Data::Dumper::Indent = 2;

$tt->process(
    "pf-switch-acls.pm.tt",
    {
        ACLsSupports => Data::Dumper->Dump([\%ACLsSupports], ['*ACLsSupports']),
        now => DateTime->now,
        class => 'pf::constants::switch_acls',
    },
    "switch_acls.pm",
) or die $tt->error();

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

