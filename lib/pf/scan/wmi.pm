package pf::scan::wmi;

=head1 NAME

pf::scan::wmi

=cut

=head1 DESCRIPTION

pf::scan::wmi is a module to add WMI scanning option.

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
use pf::scan::wmi::rules;
use pf::violation qw(violation_close);
use pf::api::jsonrpcclient;

sub description { 'WMI Scanner' }

=head1 SUBROUTINES

=over   

=item new

Create a new WMI scanning object with the required attributes

=cut

sub new {
    my ( $class, %data ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instantiating a new pf::scan::wmi scanning object");

    my $this = bless {
            '_id'       => undef,
            '_username' => undef,
            '_password' => undef,
            '_scanIp'   => undef,
            '_report'   => undef,
            '_file'     => undef,
            '_policy'   => undef,
            '_type'     => undef,
            '_status'   => undef,
            '_domain'   => undef,
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

    my $rule_tester = new pf::scan::wmi::rules;
    my $result = $rule_tester->test($this);
 
    my $scan_vid = $pf::scan::POST_SCAN_VID;
    $scan_vid = $pf::scan::SCAN_VID if ($this->{'_registration'});
    $scan_vid = $pf::scan::PRE_SCAN_VID if ($this->{'_pre_registration'});

    if (!$result) {
        $logger->warn("WMI scan didnt start");
        return $scan_vid;
    }

    my $apiclient = pf::api::jsonrpcclient->new;
    my %data = (
       'vid' => $scan_vid,
       'mac' => $this->{'_scanMac'},
    );
    $apiclient->notify('close_violation', %data );

    $this->setStatus($pf::scan::STATUS_CLOSED);
    $this->statusReportSyncToDb();
    return 0;
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
