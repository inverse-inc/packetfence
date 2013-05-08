#!/usr/bin/perl -w
=head1 NAME

dao/os.t

=head1 DESCRIPTION

Testing data access layer for the pf::os module

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 5;
use Test::NoWarnings;

use Log::Log4perl;
use Readonly;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/os.t" );
Log::Log4perl::MDC->put( 'proc', "dao/os.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use TestUtils;

# override database connection settings to connect to test database
TestUtils::use_test_db();

BEGIN { use_ok('pf::os') }

# method that we can test with a database that won't alter data and that need no parameters
my @simple_methods = qw(
    os_db_prepare
    dhcp_fingerprint_view
);

# Test methods with no parameters, assume no warnings and some results
{
    no strict 'refs';

    foreach my $method (@simple_methods) {
    
        ok(defined(&{$method}()), "testing $method call");
    }
}

Readonly my $AN_OS => {
    'id' => '1400',
    'fingerprint' => '1,28,3,15,6,12',
    'os' => 'OpenBSD',
    'classid' => '14',
    'class' => 'BSD',
};

# regression test for a regression introduced while fixing #1180 
# Someone changed the output of dhcp_fingerprint_view without realizing it was an interface contract
# used by pfdhcplistener
my @results = dhcp_fingerprint_view($AN_OS->{'fingerprint'});
is_deeply(
    \@results,
    [ $AN_OS ],
    "dhcp_fingerprint_view contract must not change! Used by pfdhcplistener. Rollback or update callers"
);

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

