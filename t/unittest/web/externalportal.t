#!/usr/bin/perl

=head1 NAME

externalportal

=head1 DESCRIPTION

The switch types the external portal URLs are rewritten to are switch modules
that support the external portal

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;

    # Stub Apache2 modules so the test can load pf::web::externalportal
    # on systems where the mod_perl2 XS libraries are not available (EL8).
    for my $mod (qw(Apache2::Const Apache2::Request Apache2::RequestRec Apache2::Connection)) {
        eval "require $mod; 1" or do {
            my $pkg = "package $mod; sub import {} 1;";
            eval $pkg;
            (my $file = "$mod.pm") =~ s|::|/|g;
            $INC{$file} = __FILE__;
        };
    }
}

use pf::web::externalportal;
use UNIVERSAL::require;

my %rewrites = %$pf::web::externalportal::SWITCH_REWRITE_MAP;

use Test::More;

#This test will running last
use Test::NoWarnings;

plan tests => 2 * (keys %rewrites) + 1;

for my $from (sort keys %rewrites) {
    my $module = "pf::Switch::$rewrites{$from}";
    ok($module =~ /^pf::Switch::\w+(?:::\w+)*$/ && $module->require(), "$from is rewritten to a switch module ($module)");
    ok($module->can('supportsExternalPortal') && $module->supportsExternalPortal, "$module supports the external portal");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
