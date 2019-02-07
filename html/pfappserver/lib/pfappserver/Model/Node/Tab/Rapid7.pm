package pfappserver::Model::Node::Tab::Rapid7;

=head1 NAME

pfappserver::Model::Node::Tab::Rapid7 -

=cut

=head1 DESCRIPTION

pfappserver::Model::Node::Tab::Rapid7

=cut

use strict;
use warnings;
use pf::Connection::ProfileFactory;
use pf::SwitchFactory;
use pf::ip4log;

=head2 process_view

Process view

=cut

sub process_view {
    my ($self, $c, @args) = @_;
    my $mac = $c->stash->{mac};
    my $scan = pf::Connection::ProfileFactory->instantiate($mac)->findScan($mac);
    if(ref($scan) ne "pf::scan::rapid7") {
        $c->log->error("The scan engine for $mac is not a Rapid7 scan engine.");
        return ($STATUS::OK, {item => undef});
    }

    my $ip = pf::ip4log::mac2ip($mac);
    return ($STATUS::OK, {
        ip => $ip,
        item => $scan->assetDetails($ip),
        device_profiling => $scan->deviceProfiling($ip),
        top_vulnerabilities => $scan->assetTopVulnerabilities($ip),
        last_scan => $scan->lastScan($ip),
        scan_templates => $scan->listScanTemplates(),
    });
}

=head2 process_tab

Process tab

=cut

sub process_tab {
    my ($self, $c, @args) = @_;
    return ($STATUS::OK, {});
}

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
