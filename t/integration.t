#!/usr/bin/perl -w

=head1 NAME

integration.t

=head1 DESCRIPTION

More intrusive tests that will start / stop daemons and expect some special files.

=cut

use strict;
use warnings;
use diagnostics;

use Test::More tests => 10;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use English qw( -no_match_vars );
use File::Basename qw(basename);
use Log::Log4perl;

Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use_ok('pf::services') }

my $return_value;

# exit codes
`/usr/local/pf/bin/pfcmd manage deregister f0:4d:a2:cb:d9:c5`;
is($CHILD_ERROR, 0, "pfcmd manage deregister exit code should be 0");

# FIXME untestable at this point, we would need to inject our switches.conf (ENV_VAR?)
#`/usr/local/pf/bin/pfcmd_vlan -deauthenticateDot1x -switch 10.0.0.1 -mac f0:4d:a2:cb:d9:c5`;
#is($CHILD_ERROR, 0, "pfcmd_vlan deauth exit code should be 0");

# TODO inject traps provoking reactions
# this one here reproduces #1098
#`echo '2011-05-19|19:36:21|UDP: [10.0.0.51]:1025|10.0.0.51|BEGIN TYPE 6 END TYPE BEGIN SUBTYPE .5 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.4.1.45.1.6.5.3.12.1.1.1.24 = INTEGER: 1|.1.3.6.1.4.1.45.1.6.5.3.12.1.2.1.24 = INTEGER: 24|.1.3.6.1.4.1.45.1.6.5.3.12.1.3.1.24 = STRING: "\\\\&
#8xG" END VARIABLEBINDINGS' >> "/usr/local/pf/logs/snmptrapd.log"`;

# TODO do tests for all other services handled by pf::services

# TODO do a node_add then a node_view and expect everything to be correct

# TODO add a config test for the presence of a vip tag in $management_network interface

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

