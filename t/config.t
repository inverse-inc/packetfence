#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More;
use Test::NoWarnings;
use Config::IniFiles;

my %default_cfg;
my %doc;

tie %default_cfg, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/pf.conf.defaults" );
tie %doc, 'Config::IniFiles',
    ( -file => "/usr/local/pf/conf/documentation.conf" );

#plan the number of tests
my $testNb = 0;
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            $testNb++;
        }
    }
}
foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies') && ($section ne 'passthroughs') ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if ( ($1 ne 'interface') && ($1 ne 'services') 
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
            ) {
                $testNb++;
            }
        } else {
            die("unable to parse section $section");
        }
    }
}

# +2 NoWarnings, use_ok 
# +4 is_in_list
# +9 normalize_time
plan tests => $testNb + 2 + 4 + 9;

use_ok('pf::config');

#run the tests
foreach my $section ( tied(%default_cfg)->Sections ) {
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        if ($section ne 'proxies') {
            my $param = "$section.$key";
            ok ( exists($doc{$param}{'description'}),
                 "$param is documented" );
        }
    }
}

foreach my $section ( tied(%doc)->Sections ) {
    if ( ($section ne 'proxies')
        && ($section ne 'passthroughs')
        ) {
        if ($section =~ /^([^.]+)\.(.+)$/) {
            if ( ($1 ne 'interface') && ($1 ne 'services')
                 && (! ( ($1 eq 'alerting') && ($2 eq 'fromaddr') ) )
               ) {
                ok ( exists($default_cfg{$1}{$2}),
                     "$section has default value" );
            }
        } else {
            die("unable to parse section $section");
        }
    }
}

ok(is_in_list("sms","sms,email"), "is_in_list positive");
ok(!is_in_list("sms","email"), "is_in_list negative");
ok(!is_in_list("sms",""), "is_in_list empty list");
ok(is_in_list("sms","sms, email"), "is_in_list positive with spaces");

# normalize time
is(normalize_time("5Z"), 0, "illegal normalize attempt");
is(normalize_time("5"), 5, "normalizing w/o a time resolution specified (seconds assumed)");
is(normalize_time("2s"), 2 * 1, "normalizing seconds");
is(normalize_time("2m"), 2 * 60, "normalizing minutes");
is(normalize_time("2h"), 2 * 60 * 60, "normalizing hours");
is(normalize_time("2D"), 2 * 24 * 60 * 60, "normalizing days");
is(normalize_time("2W"), 2 * 7 * 24 * 60 * 60, "normalizing weeks");
is(normalize_time("2M"), 2 * 30 * 24 * 60 * 60, "normalizing months");
is(normalize_time("2Y"), 2 * 365 * 24 * 60 * 60, "normalizing years");

# TODO add tests for configfile import / export

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

