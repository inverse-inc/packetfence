#!/usr/bin/perl
=head1 NAME

integration/pfcmd.t

=head1 DESCRIPTION

Testing the bin/pfcmd binary.
This module has side effect on configuration files.

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 5;
use Test::NoWarnings;

use English '-no_match_vars';
use Log::Log4perl;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "integration/pfcmd.t" );
Log::Log4perl::MDC->put( 'proc', "integration/pfcmd.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

# copying current config
`cp /usr/local/pf/conf/pf.conf /usr/local/pf/conf/pf.conf-integration-tests.bkp`;

my $pfcmd_set_config_stdout = `/usr/local/pf/bin/pfcmd config set general.hostname=initech`;
is($CHILD_ERROR >> 8, 0, "pfcmd set config exit with status 0"); 

my $pfcmd_get_config_stdout = `/usr/local/pf/bin/pfcmd config get general.hostname`;
is($CHILD_ERROR >> 8, 0, "pfcmd get config exit with status 0"); 
like($pfcmd_get_config_stdout, qr/initech/, "pfcmd set config worked"); 

my $pfcmd_set_config_empty_stdout = `/usr/local/pf/bin/pfcmd config set guests_self_registration.modes=`;
is($CHILD_ERROR >> 8, 0, "pfcmd set config with empty value (bug 1361)"); 

# put back config before the tests
`cp /usr/local/pf/conf/pf.conf-integration-tests.bkp /usr/local/pf/conf/pf.conf`; 
`rm /usr/local/pf/conf/pf.conf-integration-tests.bkp`; 

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

