#!/usr/bin/perl

=head1 NAME

scan_fetch_report.cgi - handle openvas scanning engine callback report using escalators

=cut

use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use POSIX;

use lib '/usr/local/pf/lib';

use pf::config;
use pf::scan;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('scan_fetch_report.cgi');
Log::Log4perl::MDC->put('proc', 'scan_fetch_report.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});
my %params;

# Pull parameters from query string
foreach my $param($cgi->url_param()) {
    $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
    $params{$param} = $cgi->param($param);
}

# Check if there's a scan id in url, otherwise the user has nothing to do here
if ( defined($params{'scanid'}) ) {

    # Check if there's a report id associated with that scan id and if the scan status is started (is the scan id valid)
    # otherwise the user has nothing to do here
    my $scan_infos = pf::scan::retrieve_scan_infos($params{'scanid'});
    if ( $scan_infos->{'report_id'} && ($scan_infos->{'status'} eq 'started') ) {

        $logger->info("Received a hit to get openvas scanning engine report for scan id $params{'scanid'}");

        # Fetching scan attributes to instantiate a scan object and then get the report
        my $type = $scan_infos->{'type'};
        my %scan_attributes = (
                _id         => $params{'scanid'},
                _host       => $Config{'scan'}{'host'},
                _port       => $Config{'scan'}{'port'},
                _user       => $Config{'scan'}{'user'},
                _pass       => $Config{'scan'}{'pass'},
                _reportId   => $scan_infos->{'report_id'},
        );

        my $scan = pf::scan::instantiate_scan_engine($type, %scan_attributes);
        $scan->getReport();

        # We need to manipulate the scan report.
        # Each line of the scan report is pushed into an array
        my @scan_report = split("\n", $scan->{'_report'});

        pf::scan::parse_scan_report(\@scan_report,
            'type' => $type,
            'ip' => $scan_infos->{'ip'},
            'mac' => $scan_infos->{'mac'},
            'report_id' => $scan_infos->{'report_id'},
        );
    }

# There's no scan id in the url or the scan doesn't have a report_id or a valid state
# User has nothing to do here
} else {
    $logger->info("User has nothing to do here, redirecting to ". $Config{'trapping'}{'redirecturl'});
    print $cgi->redirect($Config{'trapping'}{'redirecturl'});
}

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2012 Inverse inc.
    
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
