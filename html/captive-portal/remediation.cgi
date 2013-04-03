#!/usr/bin/perl

=head1 NAME

remediation.cgi 

=head1 SYNOPSYS

TODO

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::class;
use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
# called last to allow redefinitions
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('remediation.cgi');
Log::Log4perl::MDC->put('proc', 'remediation.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $mac = $portalSession->getClientMac();
$logger->info($portalSession->getClientIp() . " - " . $mac . " on remediation page");

# pull browser user-agent string, it is most likely more accurate than using user_agent from node_info
$portalSession->stash->{'user_agent'} = $cgi->user_agent;

# check for open violations
my $violation = violation_view_top($mac);

if ($violation) {
    my $vid = $violation->{'vid'};
    my $class = class_view($vid);
    
    my $url = "violations/" . $class->{'template'} . '.html';
    $logger->info("Showing the " . $url . " remediation page.");
    
    $portalSession->stash->{'sub_template'} = $url;

    pf::web::generate_violation_page($portalSession, $class->{'template'});
} else {
    $logger->info("No open violation for " . $mac);
    # TODO - rework to not show "Your computer was not found in the PacketFence database. Please reboot to solve this issue."
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
}

exit(0);

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
