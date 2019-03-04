#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

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
    next if $section eq 'proxies';
    $testNb += scalar keys( %{ $default_cfg{$section} } );
}
foreach my $section ( tied(%doc)->Sections ) {
    next if $section eq 'proxies' || exists $doc{$section}{guide_anchor};
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

# +2 NoWarnings, use_ok
# +15 pf::config::access_duration
plan tests => $testNb + 2 + 15;

use_ok('pf::config');

#run the tests
foreach my $section ( tied(%default_cfg)->Sections ) {
    next if $section eq 'proxies';
    foreach my $key ( keys( %{ $default_cfg{$section} } ) ) {
        my $param = "$section.$key";
        ok ( exists($doc{$param}{'description'}),
             "$param is documented" );
    }
}

foreach my $section ( tied(%doc)->Sections ) {
    next if exists $doc{$section}{guide_anchor};
    next if $section eq 'proxies';
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

my $tsformat = "%Y-%m-%d %H:%M:%S";
my $refdate = POSIX::mktime(0,0,12,2,0,101); # 2001-01-02 12:00:00 (Tuesday)
# print POSIX::strftime("$tsformat (%A)", localtime($refdate)),"\n";
is(pf::config::access_duration("2D", $refdate), POSIX::strftime($tsformat, localtime($refdate + 2 * 24 * 60 * 60)), "access duration in days");
is(pf::config::access_duration("2M", $refdate), POSIX::strftime($tsformat, localtime($refdate + 2 * 30 * 24 * 60 * 60)), "access duration in months");
is(pf::config::access_duration("2Y", $refdate), POSIX::strftime($tsformat, localtime($refdate + 2 * 365 * 24 * 60 * 60)), "access duration in years");
# duration relative to the beggining of the day
is(pf::config::access_duration("1DR+0D", $refdate), POSIX::strftime($tsformat, localtime($refdate + 1 * 24 * 60 * 60 - 12 * 60 * 60)), "relative duration by day");
is(pf::config::access_duration("1DR+2D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (1+2) * 24 * 60 * 60 - 12 * 60 * 60)), "relative duration by day");
is(pf::config::access_duration("2DR-0D", $refdate), POSIX::strftime($tsformat, localtime($refdate + 2 * 24 * 60 * 60 - 12 * 60 * 60)), "negative relative duration by day");
is(pf::config::access_duration("1WR+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (7-1+1) * 24 * 60 * 60 - 12 * 60 * 60)), "relative duration by week");
is(pf::config::access_duration("2WR+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (7-1+7+1) * 24 * 60 * 60 - 12 * 60 * 60)), "relative duration by two week");
is(pf::config::access_duration("1WR-1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (7-1-1) * 24 * 60 * 60 - 12 * 60 * 60)), "negative relative duration by week");
is(pf::config::access_duration("2MR+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (31-1+28+1) * 24 * 60 * 60 - 12 * 60 * 60)), "relative duration by month");
is(pf::config::access_duration("1YR+2M", $refdate), POSIX::strftime($tsformat, localtime(POSIX::mktime(0,0,0,1,0,102,0,0,0) + 2 * 30 * 24 * 60 * 60)), "relative duration by year");
is(pf::config::access_duration("1DF+2D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (1+2) * 24 * 60 * 60 - 12 * 60 * 60)), "fixed duration by day");
is(pf::config::access_duration("1WF+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (7+1) * 24 * 60 * 60 - 12 * 60 * 60)), "fixed duration by week");
is(pf::config::access_duration("1MF+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (30+1) * 24 * 60 * 60 - 12 * 60 * 60)), "fixed duration by month");
is(pf::config::access_duration("1YF+1D", $refdate), POSIX::strftime($tsformat, localtime($refdate + (365+1) * 24 * 60 * 60 - 12 * 60 * 60)), "fixed duration by year");

# TODO add tests for configfile import / export

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

