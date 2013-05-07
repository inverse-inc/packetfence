#!/usr/bin/perl

=head1 NAME

soh.t - Tests for pf::soh

=head1 DESCRIPTION

Tests for the SoH parser and evaluator in pf::soh.

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 19;
use Test::NoWarnings;

use File::Basename qw(basename);

use pf::config;

# Log in test log
Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

require_ok('pf::soh');
require_ok('pf::soh::custom');

my $soh = pf::soh::custom->new();
ok(defined $soh, "Can create pf::soh object");

# First, we exercise the parser a little.

ok(!$soh->parse_request({}), "Won't accept empty request");

my $res = $soh->parse_request({
    "NAS-Port" => 42,
    "User-Name" => "Kim",
    "SoH-MS-Machine-Role" => "client",
    "SoH-MS-Machine-Name" => "breflabb",
    "SoH-MS-Correlation-Id" => "0123456789",
    "SoH-MS-Machine-OS-vendor" => "Microsoft",
    "SoH-MS-Machine-OS-version" => 6,
    "SoH-MS-Machine-OS-release" => 1,
    "SoH-MS-Machine-SP-version" => 1,
    "SoH-MS-Machine-SP-release" => 0,
    "SoH-MS-Windows-Health-Status" => [
        "firewall ok snoozed=0 microsoft=1 up2date=1 enabled=1",
        "firewall ok snoozed=0 microsoft=0 up2date=1 enabled=0",
        "antivirus error not-installed",
        "antispyware ok snoozed=0 microsoft=1 up2date=1 enabled=1",
        "auto-updates ok action=install",
        "security-updates warn some-missing"
    ],
    "Calling-Station-Id" => "01-02-03-04-05-06"
});

ok(defined $res, "Can parse valid SoH request");
is(scalar keys %{$soh->{status}}, 5, "Five classes identified");
is($soh->{mac_address}, "01:02:03:04:05:06", "MAC identified correctly");
is(
    $soh->{client_description},
    "client breflabb (MAC: 01-02-03-04-05-06; Port: 42; User: Kim; ".
    "OS: Microsoft Windows 7 (or Server 2008 R2), sp 1; id: 0123456789)",
    "Client described correctly"
);

# Next, instead of calling evaluate (and having to provide a mock object
# that doesn't try to clear or add violations), we sneak behind its back
# and test matches and matches_one directly. (Unfortunately, this means
# the tests log messages to packetfence.log. Didn't seem worth fixing.)

is(
    $soh->matches_one(
        { class => "antivirus", op => "is", status => "ok" },
        $soh->{status}{antivirus}[0]
    ), 0, "Can identify that antivirus is not ok"
);

is(
    $soh->matches_one(
        { class => "antivirus", op => "isnot", status => "ok" },
        $soh->{status}{antivirus}[0]
    ), 1, "Can identify that antivirus is-not ok"
);

is(
    $soh->matches_one(
        { class => "antivirus", op => "isnot", status => "ok,microsoft" },
        $soh->{status}{antivirus}[0]
    ), 1, "Can identify that antivirus is-not ok"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "is", status => "ok,microsoft" },
        $soh->{status}{firewall}[0]
    ), 1, "Can identify that firewall is microsoft+ok"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "is", status => "ok,microsoft" },
        $soh->{status}{firewall}[1]
    ), 0, "Can identify that firewall isnot microsoft+ok"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "isnot", status => "ok,microsoft" },
        $soh->{status}{firewall}[1]
    ), 1, "Can identify that firewall isnot microsoft+ok"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "is", status => "ok,!microsoft" },
        $soh->{status}{firewall}[1]
    ), 1, "Can identify that firewall is ok+!microsoft"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "isnot", status => "disabled,microsoft" },
        $soh->{status}{firewall}[1]
    ), 1, "Can identify that firewall isnot disabled+microsoft"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "is", status => "ok,!snoozed,!microsoft,!disabled" },
        $soh->{status}{firewall}[1]
    ), 1, "Can identify that firewall is ok+!snoozed+!microsoft+!disabled"
);

is(
    $soh->matches_one(
        { class => "firewall", op => "isnot", status => "!ok,microsoft" },
        $soh->{status}{firewall}[1]
    ), 1, "Can identify that firewall isnot !ok+microsoft"
);

# XXX We could always use more tests XXX

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

=cut
