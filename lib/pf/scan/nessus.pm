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
use Net::Nessus::XMLRPC;

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
            '_host'     => $Config{'scan'}{'host'},
            '_port'     => undef,
            '_user'     => $Config{'scan'}{'user'},
            '_pass'     => $Config{'scan'}{'pass'},
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

    # Nessus specific attributes
    $this->{_port} = $Config{'scan'}{'nessus_port'};
    $this->{_policy} = $Config{'scan'}{'nessus_clientpolicy'};

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
    my $host                = $this->{_host};
    my $port                = $this->{_port};
    my $user                = $this->{_user};
    my $pass                = $this->{_pass};
    my $nessus_clientpolicy = $this->{_policy};
    my $n = Net::Nessus::XMLRPC->new ('https://'.$host.':'.$port.'/',$user,$pass);

    # select nessus policy on the server, set scan name and launch the scan
    my $polid=$n->policy_get_id($nessus_clientpolicy);
    my $scanname="pf-".$hostaddr;
    my $scanid=$n->scan_new($polid,$scanname,$hostaddr);
    $logger->info("executing Nessus scan");
    $this->{'_status'} = $pf::scan::STATUS_STARTED;
    $this->statusReportSyncToDb();

    # Wait the scan to finish
    while (not $n->scan_finished($scanid)) {
        $logger->info("Nessus is scanning $hostaddr");
        sleep 15;
    }
    
    # Get the report
    $this->{'_report'} = $n->report_filenbe_download($scanid);
    # Clean the report
    $this->{'_report'} = [ split("\n", $this->{'_report'}) ];

    pf::scan::parse_scan_report($this);
}

=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2012 Inverse inc.

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
