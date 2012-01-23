package pf::scan;

=head1 NAME

pf::scan - module that perform the vulnerabilty scan operations

=cut

=head1 DESCRIPTION

pf::scan contains the functions necessary to 

=cut

use strict;
use warnings;

use Log::Log4perl;
use Parse::Nessus::NBE;
use Readonly;

use pf::config;
use pf::iplog qw(ip2mac);
use pf::scan::nessus;
use pf::scan::openvas;
use pf::util;
use pf::violation qw(violation_exist_open violation_trigger violation_modify);

Readonly our $LOGGER_SCOPE      => 'pf::scan';
Readonly our $SCAN_VID          => 1200001;
Readonly our $SEVERITY_HOLE     => 1;
Readonly our $SEVERITY_WARNING  => 2;
Readonly our $SEVERITY_INFO     => 3;

=head1 DATABASE HANDLING

The following are required for database handling magic (see pf::db)

=cut

use constant SCAN => 'scan';
BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw( runScan $SCAN_VID $scan_db_prepared scan_db_prepare );
    @EXPORT_OK = qw(
        scan_add_sql
        scan_modify_sql
    );
}

our $scan_db_prepared = 0;
our $scan_statements = {};

sub scan_db_prepare {
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $logger->debug("Preparing pf::scan database queries");

    $scan_statements->{'scan_add_sql'} = get_db_handle()->prepare(qq[
            INSERT INTO scan (
                id, mac, start_date, update_date, status, result
            ) VALUES (
                ?, ?, ?, ?, ?
            )
    ]);

    $scan_statements->{'scan_modify'} = get_db_handle()->prepare(qq[
            UPDATE scan SET
                status = ?, result = ?
            WHERE id = ?
    ]);

    $scan_db_prepared = 1;
    return 1;
}

=head1 SUBROUTINES

=over   

=item generate_new_scan_id - Generate a new unique id for the upcoming scan

The scan id will be the epoch + 2 random numbers + the last four characters of the mac address

=cut
sub generate_new_scan_id {
    my ( $epoch, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $logger->debug("Generating a new scan ID");

    # Generate 2 random numbers
    # the number 100 is to permit a 2 digits random number
    my $random = int(rand(100));

    # Get the four last characters of the mac address
    $mac =~ s/\://g;
    $mac = substr($mac, -4);

    my $id = $epoch.$random.$mac;

    $logger->info("New scan ID generated: $id");

    return $id;
}

=item instantiate_scan_engine

Instantiate the correct scanning engine with some attributes according to the config file

=cut
sub instantiate_scan_engine {
    my ( $id, $scan_host, $scan_mac ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    my $scan_engine     = 'pf::scan::' . $Config{'scan'}{'engine'};
    my %scan_options    = (
            _host       => $Config{'scan'}{'host'},
            _port       => $Config{'scan'}{'port'},
            _user       => $Config{'scan'}{'user'},
            _pass       => $Config{'scan'}{'pass'},
            _id         => $id,
            _scanHost   => $scan_host,
            _scanMac    => $scan_mac,
    );

    $logger->info("Instantiate a new scan engine of type $scan_engine");

    return $scan_engine->new(%scan_options);
}

=item parse_scan_report

Receive the scan report in NBE format and parse it accoding to the different severity levels

=cut
sub parse_scan_report {
    my ( $report ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);
}

=item runScan

=cut
sub runScan {
    my ( $hostaddr, %params ) = @_;
    my $logger = Log::Log4perl::get_logger($LOGGER_SCOPE);

    $hostaddr =~ s/\//\\/g;             # escape slashes
    $hostaddr = clean_ip($hostaddr);    # untainting ip

    # Resolve mac address
    my $mac = ip2mac($hostaddr);
    if ( !$mac ) {
        $logger->warn("Unable to find MAC for the scanned host $hostaddr. Scan aborted!");
        return 0;
    }

    # Make sure the mac address format is correct
    my $tmpMac = Net::MAC->new('mac' => $mac);
    $mac = $tmpMac->as_IEEE();

    # Preparing the scan
    my $epoch = time;
    my $id = generate_new_scan_id($epoch, $mac);

    # Instantiate the new scan object
    my $scan = instantiate_scan_engine($id, $hostaddr, $mac);

    # Start the scan
    $scan->startScan();
}

=back

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

1;
