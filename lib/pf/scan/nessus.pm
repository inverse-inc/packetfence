package pf::scan::nessus;

=head1 NAME

pf::scan::nessus

=cut

=head1 DESCRIPTION

pf::scan::nessus is a module to add Nessus scanning option.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Readonly;

use base ('pf::scan');

use pf::config;
use pf::scan;
use pf::util;
use pf::node;
use Net::Nessus::XMLRPC;

sub description { 'Nessus Scanner' }

=head1 SUBROUTINES

=over   

=item new

Create a new Nessus scanning object with the required attributes

=cut

sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instantiating a new pf::scan::nessus scanning object");

    my $this = bless {
            '_id'       => undef,
            '_ip'       => undef,
            '_port'     => undef,
            '_username' => undef,
            '_password' => undef,
            '_scanIp'   => undef,
            '_scanMac'  => undef,
            '_report'   => undef,
            '_file'     => undef,
            '_policy'   => undef,
            '_type'     => undef,
            '_status'   => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{'_' . $value} = $data{$value};
    }

    return $this;
}

=item startScan

=cut

# WARNING: A lot of extra single quoting has been done to fix perl taint mode issues: #1087
sub startScan {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # nessus scan setup
    my $id                  = $this->{_id};
    my $hostaddr            = $this->{_scanIp};
    my $mac                 = $this->{_scanMac};
    my $host                = $this->{_ip};
    my $port                = $this->{_port};
    my $user                = $this->{_username};
    my $pass                = $this->{_password};
    my $nessus_clientpolicy = $this->{_nessus_clientpolicy};
    my $n = Net::Nessus::XMLRPC->new('https://'.$host.':'.$port.'/', $user, $pass);

    # select nessus policy on the server, set scan name and launch the scan
    my $polid = $n->policy_get_id($nessus_clientpolicy);
    if ($polid eq "") {
        $logger->warn("Nessus policy doesnt exist ".$nessus_clientpolicy);
        return 1;
    }
    my $scanname = "pf-".$hostaddr."-".$nessus_clientpolicy;
    my $scanid = $n->scan_new($polid, $scanname, $hostaddr);

    my $scan_vid = $pf::scan::POST_SCAN_VID;
    $scan_vid = $pf::scan::SCAN_VID if ($this->{'_registration'});

    if ( $scanid eq "") {
        $logger->warn("Nessus scan doesnt start");
        return $scan_vid;
    }
    $logger->info("executing Nessus scan with this policy ".$nessus_clientpolicy);
    $this->{'_status'} = $pf::scan::STATUS_STARTED;
    $this->statusReportSyncToDb();

    # Wait the scan to finish
    my $counter = 0;
    while (not $n->scan_finished($scanid)) {
        if ($counter > 3600) {
            $logger->info("Nessus scan is older than 1 hour ...");
            return 1;
        }
        $logger->info("Nessus is scanning $hostaddr");
        sleep 15;
        $counter = $counter + 15;
    }
    
    # Get the report
    $this->{'_report'} = $n->report_filenbe_download($scanid);
    # Remove report on the server and logout from nessus
    $n->report_delete($scanid);
    $n->DESTROY;
    # Clean the report
    $this->{'_report'} = [ split("\n", $this->{'_report'}) ];

    pf::scan::parse_scan_report($this,$scan_vid);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

1;
