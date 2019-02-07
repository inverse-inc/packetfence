#!/usr/bin/perl -w

=head1 NAME

dao/report.t

=head1 DESCRIPTION

Testing data access layer for the pf::pfcmd::report module

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 27;
use Test::NoWarnings;

use Log::Log4perl;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/report.t" );
Log::Log4perl::MDC->put( 'proc', "dao/report.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use lib qw(/usr/local/pf/t);
use TestUtils;

# override database connection settings to connect to test database
TestUtils::use_test_db();

BEGIN { use_ok('pf::pfcmd::report') }

my @methods = qw(
    report_os_all
    report_os_active
    report_osclass_all
    report_osclass_active
    report_active_all
    report_inactive_all
    report_unregistered_active
    report_unregistered_all
    report_active_reg
    report_registered_all
    report_registered_active
    report_opensecurity_events_all
    report_opensecurity_events_active
    report_statics_all
    report_statics_active
    report_unknownprints_all
    report_unknownprints_active
    report_connectiontype_all
    report_connectiontype_active
    report_connectiontypereg_all
    report_connectiontypereg_active
    report_ssid_all
    report_ssid_active
);

# Test each method, assume no warnings and results
{
    no strict 'refs';

    foreach my $method (@methods) {

        ok(defined(&{$method}()), "testing $method call");
    }
}

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

