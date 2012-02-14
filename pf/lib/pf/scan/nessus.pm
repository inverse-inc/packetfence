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

use pf::config;
use pf::scan;
use pf::util;

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
            '_host'     => undef,
            '_port'     => undef,
            '_user'     => undef,
            '_pass'     => undef,
            '_scanIp'   => undef,
            '_scanMac'  => undef,
            '_report'   => undef,
            '_file'     => undef,
            '_policy'   => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $this->{'_' . $value} = $data{$value};
    }

    # Nessus specific attributes
    $this->{_port} = $Config{'scan'}{'nessus_port'};
    $this->{_file} = $install_dir . '/conf/nessus/' . $Config{'scan'}{'nessus_clientfile'};
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
    my $nessus_clientfile   = $this->{_file};
    my $nessus_clientpolicy = $this->{_policy};
    my $nessusRcHome        = 'HOME=' . $install_dir . '/conf/nessus/';

    # preparing host to scan temporary file and result file
    my $infileName = '/tmp/pf_nessus_' . $id . '.txt';
    my $outfileName = $install_dir . '/html/admin/scan/results/dump_' . $id . '.nbe';
    my $infile_fh;
    open( $infile_fh, '>', $infileName );
    print {$infile_fh} $hostaddr;
    close( $infile_fh );

    # the scan
    my $cmd = 
        "$nessusRcHome /opt/nessus/bin/nessus -q -V -x --dot-nessus $nessus_clientfile " 
        . "--policy-name $nessus_clientpolicy $host $port $user $pass --target-file $infileName $outfileName 2>&1"
    ;
    $logger->info("executing $cmd");
    my $output = pf_run($cmd);
    unlink($infileName);

    # did it went well?
    if ($?) { $logger->warn("nessus scan failed, it returned: $output"); }
    if ( ! -r $outfileName ) {
        $logger->warn("unable to open $outfileName for reading; Nessus scan might have failed");
        return 1;
    }

    # Preparing and parsing output file
    chmod 0644, $outfileName;
    open( $infile_fh, '<', $outfileName);
    my @nessusdata = <$infile_fh>;
    close( $infile_fh );

    pf::scan::parse_scan_report(
        \@nessusdata,
        type => "nessus",
        ip => $hostaddr,
        mac => $mac,
        report_id => $outfileName,
    );
}

=back

=head1 AUTHOR

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
