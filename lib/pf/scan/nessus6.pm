package pf::scan::nessus6;

=head1 NAME

pf::scan::nessus6

=cut

=head1 DESCRIPTION

pf::scan::nessus6 is a module to add Nessus v6 scanning option.

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
use pf::constants::scan qw($SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID $STATUS_STARTED);
use Net::Nessus::REST;

sub description { 'Nessus6 Scanner' }

=head1 SUBROUTINES

=over

=item new

Create a new Nessus6 scanning object with the required attributes

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
    my $scanner_name        = $self->{_scannername};
    my $format              = $self->{_format};
    my $verify_hostname     = isenabled($self->{_verify_hostname}) ? $TRUE : $FALSE;

    my $nessus = Net::Nessus::REST->new(url => 'https://'.$host.':'.$port, ssl_opts => { verify_hostname => $verify_hostname });
    $nessus->create_session(username => $user, password => $pass);

    my $scan_security_event_id = $POST_SCAN_SECURITY_EVENT_ID;
    $scan_security_event_id = $SCAN_SECURITY_EVENT_ID if ($self->{'_registration'});
    $scan_security_event_id = $PRE_SCAN_SECURITY_EVENT_ID if ($self->{'_pre_registration'});

    # Verify nessus policy ID on the server, nessus remote scanner id, set scan name and launch the scan

    my $policy_id = $nessus->get_policy_id(name => $nessus_clientpolicy);
    if ($policy_id eq "") {
        $logger->warn("Nessus policy doesnt exist ".$nessus_clientpolicy);
        return $scan_security_event_id;
    }

    my $scanner_id = $nessus->get_scanner_id(name => $scanner_name);
    if ($scanner_id eq ""){
        $logger->warn("Nessus scanner name doesn't exist ".$scanner_id);
        return $scan_security_event_id;
    }

    #This is neccesary because the way of the new nessus API works, if the scan fails most likely
    # is in this function.
    my $policy_uuid = $nessus->get_template_id( name => 'custom', type => 'scan');
    if ($policy_uuid eq ""){
        $logger->warn("Failled to obtain the uuid for the policy ".$policy_uuid);
        return $scan_security_event_id;
    }


    #Create the scan into the Nessus web server with the name pf-hostaddr-policyname
    my $scan_name = "pf-".$hostaddr."-".$nessus_clientpolicy;
    my $scan_id = $nessus->create_scan(
        uuid => $policy_uuid,
        settings => {
            text_targets => $hostaddr,
            name => $scan_name,
            scanner_id => $scanner_id,
            policy_id => $policy_id
        }
    );
    if ( $scan_id eq "") {
        $logger->warn("Failled to create the scan");
        return $scan_security_event_id;
    }

    $nessus->launch_scan(scan_id => $scan_id->{id});

    $logger->info("executing Nessus scan with this policy ".$nessus_clientpolicy);
    $self->{'_status'} = $pf::scan::STATUS_STARTED;
    $self->statusReportSyncToDb();


    # Wait the scan to finish
    my $counter = 0;
    while ($nessus->get_scan_status(scan_id => $scan_id->{id}) ne 'completed') {
        if ($counter > 3600) {
            $logger->info("Nessus scan is older than 1 hour ...");
            return $scan_security_event_id;
        }
        $logger->info("Nessus is scanning $hostaddr");
        sleep 15;
        $counter = $counter + 15;
    }

    # Get the report
    my $file_id = $nessus->export_scan(scan_id => $scan_id->{id}, format => $format);
    while ($nessus->get_scan_export_status(scan_id => $scan_id->{id},file_id => $file_id) ne 'ready') {
        sleep 2;
    }
    $self->{'_report'} = $nessus->download_scan(scan_id => $scan_id->{id}, file_id => $file_id);
    # Remove report on the server and logout from nessus
    $nessus->delete_scan(scan_id => $scan_id->{id});
    $nessus->DESTROY;

    pf::scan::parse_scan_report($self,$scan_security_event_id);
}

=back

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

1;
