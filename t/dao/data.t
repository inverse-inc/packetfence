#!/usr/bin/perl
=head1 NAME

data.t

=head1 DESCRIPTION

Test conformance of the data accessors to the database layer interface.

=cut
use strict;
use warnings;
use diagnostics;

use Test::More tests => 112;
use Test::NoWarnings;
use lib '/usr/local/pf/lib';

use Log::Log4perl;
use Readonly;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/data.t" );
Log::Log4perl::MDC->put( 'proc', "dao/data.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use TestUtils;

# override database connection settings to connect to test database
TestUtils::use_test_db();

# Test all modules that provides data
BEGIN { use_ok('pf::db') }
BEGIN { 
    use_ok('pf::action');
    use_ok('pf::billing');
    use_ok('pf::class');
    use_ok('pf::configfile');
    use_ok('pf::email_activation');
    use_ok('pf::freeradius');
    use_ok('pf::ifoctetslog');
    use_ok('pf::iplog');
    use_ok('pf::locationlog');
    use_ok('pf::node');
    use_ok('pf::nodecategory');
    use_ok('pf::os');
    use_ok('pf::person');
    use_ok('pf::scan');
    use_ok('pf::switchlocation');
    use_ok('pf::traplog');
    use_ok('pf::trigger');
    use_ok('pf::useragent');
    use_ok('pf::violation');
    use_ok('pf::pfcmd::dashboard');
    use_ok('pf::pfcmd::graph');
    use_ok('pf::pfcmd::report');
}

my @data_modules = qw(
    pf::action
    pf::billing
    pf::class
    pf::configfile
    pf::email_activation
    pf::freeradius
    pf::ifoctetslog
    pf::iplog
    pf::locationlog
    pf::node
    pf::nodecategory
    pf::os
    pf::person
    pf::scan
    pf::switchlocation
    pf::traplog
    pf::trigger
    pf::useragent
    pf::violation
    pf::pfcmd::dashboard
    pf::pfcmd::graph
    pf::pfcmd::report
);

foreach my $module (@data_modules) {

    # setup
    # grab the portion after the last ::
    $module =~ /\w+::(\w+)$/;
    my $var = $1."_db_prepared";
    my $method = $1."_db_prepare";

    # is there a prepared variable?
    ok(defined(${$var}), "$var exposed");

    # is there a prepare method?
    can_ok($module, $method) 
        or diag("no prepare method for data module! Never do such a thing, the pf::db module expects that method.");

    {
        no strict 'refs';
        is(&{$method}(), 1, "preparing statements for $module");

        # is prepared to the right value?
        is(${$var}, 1, "data is marked as prepared");
    }
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

