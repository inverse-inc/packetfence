#!/usr/bin/perl -w
=head1 NAME

pfcmd.t

=head1 DESCRIPTION

Testing pfcmd command line interface (CLI)

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 78;
use Test::NoWarnings;

use Log::Log4perl;
use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use_ok('pf::pfcmd') }

my %cmd;

%cmd = pf::pfcmd::parseCommandLine('checkup');
is_deeply(\%cmd,
          { 'command' => [ 'checkup'] },
          'pfcmd checkup'
);

%cmd = pf::pfcmd::parseCommandLine('class view all');
is_deeply(\%cmd,
          { 'command' => [ 'class', 'view', 'all' ] },
          'pfcmd class view all');

%cmd = pf::pfcmd::parseCommandLine('config get general.hostname');
is_deeply(\%cmd,
          { 'command' => [ 'config', 'get', 'general.hostname' ] },
          'pfcmd config get general.hostname');

%cmd = pf::pfcmd::parseCommandLine('config help general.hostname');
is_deeply(\%cmd,
          { 'command' => [ 'config', 'help', 'general.hostname' ] },
          'pfcmd config help general.hostname');

%cmd = pf::pfcmd::parseCommandLine('config set general.hostname=packetfence');
is_deeply(\%cmd,
          { 'command' => [ 'config', 'set', 'general.hostname=packetfence' ] },
          'pfcmd config set general.hostname=packetfence');

%cmd = pf::pfcmd::parseCommandLine('config set proxies.tools/stinger.exe=http://download.nai.com/products/mcafee-avert/stng260.bin');
is_deeply(\%cmd,
          { 'command' => [ 'config', 'set', 'proxies.tools/stinger.exe=http://download.nai.com/products/mcafee-avert/stng260.bin' ] },
          'pfcmd config set proxies.tools/stinger.exe=http://download.nai.com/products/mcafee-avert/stng260.bin');

%cmd = pf::pfcmd::parseCommandLine('configfiles pull');
is_deeply(\%cmd,
          { 'command' => [ 'configfiles', 'pull' ] },
          'pfcmd configfiles pull');

%cmd = pf::pfcmd::parseCommandLine('configfiles push');
is_deeply(\%cmd,
          { 'command' => [ 'configfiles', 'push' ] },
          'pfcmd configfiles push');

%cmd = pf::pfcmd::parseCommandLine('fingerprint view all');
is_deeply(\%cmd,
          { 'command' => [ 'fingerprint', 'view', 'all' ] },
          'pfcmd fingerprint view all');

%cmd = pf::pfcmd::parseCommandLine('graph toto');
is_deeply(\%cmd,
          { 'command' => [ 'help', 'graph' ] },
          'pfcmd graph toto');

%cmd = pf::pfcmd::parseCommandLine('graph nodes');
is_deeply(\%cmd,
          { 'command' => [ 'graph', 'nodes' ] },
          'pfcmd graph nodes');

%cmd = pf::pfcmd::parseCommandLine('graph registered month');
is_deeply(\%cmd,
          { 'command' => [ 'graph', 'registered', 'month' ] },
          'pfcmd graph registered month');

%cmd = pf::pfcmd::parseCommandLine('help graph');
is_deeply(\%cmd,
          { 'command' => [ 'help', 'graph' ] },
          'pfcmd help graph');

%cmd = pf::pfcmd::parseCommandLine('history 192.168.0.1');
is_deeply(\%cmd,
          { 'command' => [ 'history', '192.168.0.1' ] },
          'pfcmd history 192.168.0.1');

%cmd = pf::pfcmd::parseCommandLine('interfaceconfig get all');
is_deeply(\%cmd,
          { 'command' => [ 'interfaceconfig', 'get', 'all' ] },
          'pfcmd interfaceconfig get all');

%cmd = pf::pfcmd::parseCommandLine('lookup person 1');
is_deeply(\%cmd,
          { 'command' => [ 'lookup', 'person', '1' ] },
          'pfcmd lookup person 1');

%cmd = pf::pfcmd::parseCommandLine('manage freemac 00:00:00:00:00:01');
is_deeply(\%cmd,
          { 'command' 
              => [ 'manage', 'freemac', '00:00:00:00:00:01' ],
            'manage_options'
              => [ 'freemac', '00:00:00:00:00:01' ]
          },
          'pfcmd manage freemac 00:00:00:00:00:01');

%cmd = pf::pfcmd::parseCommandLine('networkconfig get all');
is_deeply(\%cmd,
          { 'command' => [ 'networkconfig', 'get', 'all' ] },
          'pfcmd networkconfig get all');

%cmd = pf::pfcmd::parseCommandLine('node view all');
is_deeply(\%cmd,
          { 'command' 
              => [ 'node', 'view', 'all' ],
            'node_options'
              => [ 'view', 'all' ],
          },
          'pfcmd node view all');

%cmd = pf::pfcmd::parseCommandLine('node view all order by mac asc');
is_deeply(\%cmd,
          { 'command' 
              => [ 'node', 'view', 'all', 'order', 'by', 'mac', 'asc' ],
            'node_options'
              => [ 'view', 'all' ],
            'orderby_options'
              => [ 'order', 'by', 'mac', 'asc' ]
          },
          'pfcmd node view all order by mac asc');

%cmd = pf::pfcmd::parseCommandLine('node view all limit 2,1');
is_deeply(\%cmd,
          { 'command' 
              => [ 'node', 'view', 'all', 'limit', '2', '1' ],
            'node_options'
              => [ 'view', 'all' ],
            'limit_options'
              => [ 'limit', '2', ',', '1' ]
          },
          'pfcmd node view all limit 2,1');

%cmd = pf::pfcmd::parseCommandLine('nodecategory view all');
is_deeply(\%cmd,
          { 'command' 
                => [ 'nodecategory', 'view', 'all' ],
            'nodecategory_options'
              => [ 'view', 'all' ]
          },
          'pfcmd nodecategory view all');

%cmd = pf::pfcmd::parseCommandLine('person view all');
is_deeply(\%cmd,
          { 'command' 
              => [ 'person', 'view', 'all' ],
            'person_options'
              => [ 'view', 'all' ]
          },
          'pfcmd person view all');

%cmd = pf::pfcmd::parseCommandLine('reload fingerprints');
is_deeply(\%cmd,
          { 'command' => [ 'reload', 'fingerprints' ] },
          'pfcmd reload fingerprints');

%cmd = pf::pfcmd::parseCommandLine('report active');
is_deeply(\%cmd,
          { 'command' => [ 'report', 'active' ] },
          'pfcmd report active');

%cmd = pf::pfcmd::parseCommandLine('schedule view all');
is_deeply(\%cmd,
          { 'command' 
              => [ 'schedule', 'view', 'all' ],
            'schedule_options'
              => [ 'view', 'all' ]
          },
          'pfcmd schedule view all');

%cmd = pf::pfcmd::parseCommandLine('service pf status');
is_deeply(\%cmd,
          { 'command' => [ 'service', 'pf', 'status' ] },
          'pfcmd service pf status');

%cmd = pf::pfcmd::parseCommandLine('switchconfig get all');
is_deeply(\%cmd,
          { 'command' => [ 'switchconfig', 'get', 'all' ] },
          'pfcmd switchconfig get all');

%cmd = pf::pfcmd::parseCommandLine('floatingnetworkdeviceconfig get all');
is_deeply(\%cmd,
          { 'command' => [ 'floatingnetworkdeviceconfig', 'get', 'all' ] },
          'pfcmd floatingnetworkdeviceconfig get all');

%cmd = pf::pfcmd::parseCommandLine('traplog update');
is_deeply(\%cmd,
          { 'command' => [ 'traplog', 'update' ] },
          'pfcmd traplog update');

%cmd = pf::pfcmd::parseCommandLine('trigger view all');
is_deeply(\%cmd,
          { 'command' => [ 'trigger', 'view', 'all' ] },
          'pfcmd trigger view all');

%cmd = pf::pfcmd::parseCommandLine('ui menus');
is_deeply(\%cmd,
          { 'command' => [ 'ui', 'menus' ] },
          'pfcmd ui menus');

%cmd = pf::pfcmd::parseCommandLine('update oui');
is_deeply(\%cmd,
          { 'command' => [ 'update', 'oui' ] },
          'pfcmd update oui');

%cmd = pf::pfcmd::parseCommandLine('version');
is_deeply(\%cmd,
          { 'command' => [ 'version'] },
          'pfcmd version');

%cmd = pf::pfcmd::parseCommandLine('violation view 1');
is_deeply(\%cmd,
          { 'command' 
              => [ 'violation', 'view', '1' ],
            'violation_options'
              => [ 'view', '1' ],
          },
          'pfcmd violation view 1');

%cmd = pf::pfcmd::parseCommandLine('violationconfig get all');
is_deeply(\%cmd,
          { 'command' => [ 'violationconfig', 'get', 'all' ] },
          'pfcmd violationconfig get all');

%cmd = pf::pfcmd::parseCommandLine('import nodes filename.csv');
is_deeply(\%cmd,
          { 'command' => [ 'import', 'nodes', 'filename.csv' ] },
          'pfcmd import nodes filename.csv');

# test command line help
my @output = `/usr/local/pf/bin/pfcmd help 2>&1`;
my @main_args;
foreach my $line (@output) {
    if ($line =~ /^([^ ]+) +\|/) {
        push @main_args, $1;
    }
}

foreach my $help_arg (@main_args) {
    my @output = `/usr/local/pf/bin/pfcmd help $help_arg 2>&1`;
    like ( $output[0], qr/^Usage: pfcmd $help_arg/,
         "pfcmd $help_arg is documented" );
}

# test version
@output = `/usr/local/pf/bin/pfcmd version`;
like ( $output[0], qr'PacketFence 2.2.1',
       "pfcmd version is correct" );

# reproducing issue #1206: pid=email@address.com not accepted in pfcmd node view ...
%cmd = pf::pfcmd::parseCommandLine('node view pid=email@address.com');
is_deeply(\%cmd, { 
    'command' => [ 'node', 'view', 'pid', 'email@address.com' ],
    'node_filter' => [ [ 'pid', 'email@address.com' ] ], # node_filter[0] holds [ pid, email ]
    'node_options' => [ 'view', 'pid' ],
}, 'pfcmd node view with pid as an email');


=head1 AUTHOR

Dominik Ghel <dghel@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2011 Inverse inc.

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

