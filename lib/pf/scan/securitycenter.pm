package pf::scan::securitycenter;

=head1 NAME

pf::scan::securitycenter

=cut

=head1 DESCRIPTION

pf::scan::securitycenter is a module to add Security Center scanning option.

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
use pf::constants qw($TRUE $FALSE);
use pf::constants::scan qw($SCAN_VID $PRE_SCAN_VID $POST_SCAN_VID $STATUS_STARTED);
use Net::Nessus::SecurityCenter;
use XML::Simple qw(:strict);
use IO::Uncompress::Unzip qw(unzip $UnzipError) ;

sub description { 'Security Center' }

=head1 SUBROUTINES

=over

=item new

Create a new Security Center scanning  object with the required attributes

=cut

sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    my $self = bless {
            '_id'          => undef,
            '_host'        => undef,
            '_port'        => undef,
            '_username'    => undef,
            '_password'    => undef,
            '_scanIp'      => undef,
            '_scanMac'     => undef,
            '_report'      => undef,
            '_file'        => undef,
            '_policy'      => undef,
            '_type'        => undef,
            '_status'      => undef,
            '_scannername' => undef,
            '_format'      => 'csv',
            '_oses'        => undef,
            '_categories'  => undef,
            '_verify_hostname' => 'enabled',
    }, $class;

    foreach my $value ( keys %data ) {
        $self->{'_' . $value} = $data{$value};
    }

    return $self;
}

=item startScan

=cut

# WARNING: A lot of extra single quoting has been done to fix perl taint mode issues: #1087
sub startScan {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # nessus scan setup
    my $id                  = $self->{_id};
    my $hostaddr            = $self->{_scanIp};
    my $mac                 = $self->{_scanMac};
    my $host                = $self->{_ip};
    my $port                = $self->{_port};
    my $user                = $self->{_username};
    my $pass                = $self->{_password};
    my $nessus_clientpolicy = $self->{_nessus_clientpolicy};
    my $nessus_repository   = $self->{_nessus_repository};
    my $format              = $self->{_format};
    my $verify_hostname     = isenabled($self->{_verify_hostname}) ? $TRUE : $FALSE;

    my $nessus = Net::Nessus::SecurityCenter->new(url => 'https://'.$host.':'.$port, ssl_opts => { verify_hostname => $verify_hostname });
    $nessus->create_session(username => $user, password => $pass);

    my $scan_vid = $POST_SCAN_VID;
    $scan_vid = $SCAN_VID if ($self->{'_registration'});
    $scan_vid = $PRE_SCAN_VID if ($self->{'_pre_registration'});

    # Verify nessus policy ID on the server, nessus remote scanner id, set scan name and launch the scan
    my $policy_id = $nessus->get_policy_id(name => $nessus_clientpolicy);
    if ($policy_id eq "") {
        $logger->warn("Nessus policy doesnt exist ".$nessus_clientpolicy);
        return 1;
    }
    my $repository = $nessus->get_repository_id(name => $nessus_repository);
    if ($repository eq ""){
        $logger->warn("Nessus repository name doesn't exist ".$repository);
        return 1;
    }

    #Create the scan into the Nessus web server with the name pf-hostaddr-policyname
    my $scan_name = "PacketFence(".$mac."/".$hostaddr.")";
    my $scan_id = $nessus->create_scan(
        name => $scan_name,
        type => "policy",
        description => $id,
        repository => {
            id => $repository,
        },
        ipList => $hostaddr,
        policy => {
            id => $policy_id,
        },
        schedule => {
            type => "now",
        },
    );

    if ( $scan_id eq "") {
        $logger->warn("Failled to create the scan");
        return 1;
    }

    $logger->info("executing Nessus scan with this policy ".$nessus_clientpolicy);
    $self->{'_status'} = $pf::scan::STATUS_STARTED;
    $self->statusReportSyncToDb();

    # Wait the scan to finish
    my $counter = 0;
    while (defined($nessus->get_scan_status(scan_id => $id)) && $nessus->get_scan_status(scan_id => $id) ne "Completed") {
        if ($counter > 3600) {
            $logger->info("Nessus scan is older than 1 hour ...");
            return 1;
        }
        $logger->info("Nessus is scanning $hostaddr");
        sleep 15;
        $counter = $counter + 15;
    }
    $logger->info("Nessus scan is finished");

    my $scan_result_id = $nessus->get_scan_id(scan_id => $id);


    my $download = $nessus->download_report(
        downloadType => "v2",
        scan_id => $scan_result_id,
    );

    my $output;
    unzip \$download => \$output
        or die "unzip failed: $UnzipError\n";

    $self->{'_report'} = $output;

    #my $file_id = $nessus->export_scan(scan_id => $scan_id->{id}, format => $format);
    #while ($nessus->get_scan_export_status(scan_id => $scan_id->{id},file_id => $file_id) ne 'ready') {
    #    sleep 2;
    #}
    #$self->{'_report'} = $nessus->download_scan(scan_id => $scan_id->{id}, file_id => $file_id);
    # Remove report on the server and logout from nessus
    #$nessus->delete_scan(scan_id => $scan_id->{id});
    #$nessus->DESTROY;

    pf::scan::parse_scan_report($self,$scan_vid);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
