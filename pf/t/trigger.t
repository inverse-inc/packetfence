#!/usr/bin/perl
=head1 NAME

trigger.t

=head1 DESCRIPTION

pf::trigger module testing

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 9;
use Test::NoWarnings;
use Test::Exception;
use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { use_ok('pf::trigger') }

# subs
can_ok('pf::trigger', qw(
    trigger_db_prepare
    trigger_desc
    trigger_view
    trigger_view_enable
    trigger_view_vid
    trigger_view_tid
    trigger_view_all
    trigger_view_type
    trigger_delete_vid
    trigger_delete_all
    trigger_exist
    trigger_add
    parse_triggers
));

# trigger parsing tests
is_deeply(
    parse_triggers("Detect::1100005"),
    [ [ 1100005, 1100005, "detect" ] ],
    "parsing single trigger"
);

is_deeply(
    parse_triggers("Detect::1100005,OS::4"),
    [ [ 1100005, 1100005, "detect" ], [ 4, 4, "os" ] ],
    "parsing multiple triggers"
);

is_deeply(
    parse_triggers("Detect::1100005-1100007,OS::4"),
    [ [ 1100005, 1100007, "detect" ], [ 4, 4, "os" ] ],
    "parsing triggers with a range"
);

throws_ok { parse_triggers("Detect::1100005,OS::4,INVALID::7") }
    qr/Invalid trigger type/,
    'parsing triggers with an invalid trigger type expecting exception'
;

throws_ok { parse_triggers("Detect::1100005-1100001,OS::4") }
    qr/Invalid trigger range/,
    'parsing triggers with an invalid trigger range expecting exception'
;

throws_ok { parse_triggers("VENDORMAC::00:22:FA,VENDORMAC::00:22:68,VENDORMAC::00:13:e8") }
    qr/Invalid trigger id/,
    'parsing triggers with an invalid trigger id expecting exception'
;

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.

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

