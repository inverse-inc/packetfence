#!/usr/bin/perl

=head1 NAME

scan_fetch_report.cgi - handle openvas scanning engine callback report using escalators

=cut

use strict;
use warnings;

use lib "/usr/local/pf/lib";

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use POSIX;

use pf::class;
use pf::config;
use pf::email_activation;
use pf::iplog;
use pf::node;
use pf::util;
use pf::web;
use pf::web::guest 1.10;
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('scan_fetch_report.cgi');
Log::Log4perl::MDC->put('proc', 'scan_fetch_report.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});



my $ip              = $cgi->remote_addr();
my $mac             = ip2mac($ip);
my %params;
my %info;


# Pull parameters from query string
foreach my $param($cgi->url_param()) {
    $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
    $params{$param} = $cgi->param($param);
}

# Correct POST
if (defined($params{'reportid'})) {
    $logger->info("BOUETTE HERE'S WHAT I GOT: $params{'reportid'}");
} else {

    $logger->info("User has nothing to do here, redirecting to ".$Config{'trapping'}{'redirecturl'});
    print $cgi->redirect($Config{'trapping'}{'redirecturl'});

}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2012 Inverse inc.
    
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

