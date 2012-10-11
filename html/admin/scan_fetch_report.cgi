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
use Try::Tiny;

use lib '/usr/local/pf/lib';

use pf::config;
use pf::scan;
use pf::web qw(i18n i18n_format);
use pf::web::admin 1.00;
use pf::web::custom;

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

# Check if there's a scan id in url, otherwise no one has nothing to do here.
exit(0) if ( !defined($params{'scanid'}) );

try {

    # Fetching proper scan object
    my $scan = pf::scan::retrieve_scan($params{'scanid'});
    if ( defined($scan) && $scan->isNotExpired() ) {
        $logger->info("Received a hit to get OpenVAS scanning engine report for scan id $params{'scanid'}");
        $scan->processReport();
    }
    else {
        $logger->info("Request to fetch a scan report with unrecognized or expired scan id: $params{'scanid'}");
        pf::web::admin::generate_error_page($cgi, $session, i18n("The scan report code provided is invalid or expired."));
    }

} catch {
    chomp($_);
    $logger->error("Caught exception while processing OpenVAS scan callback: $_");
    exit(2);
};

exit(0);

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
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
