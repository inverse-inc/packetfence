package pf::import;

=head1 NAME

pf::import - module handling importation from pfcmd (and web admin)

=cut

=head1 DESCRIPTION

pf::import contains the functions necessary to manage all aspects
of bulk imports

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names 
and avoid the double naming. 

For ex: pf::import::nodes() instead of pf::import::import_nodes()

Remove this note when it will be no longer relevant. ;)

=cut

use strict;
use warnings;

use Log::Log4perl;
use Text::CSV;
use POSIX;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw();
    @EXPORT_OK = qw();
}

use pf::config;
use pf::node;
use pf::util;

=head1 SUBROUTINES

=over

=item nodes

Handle bulk importation of nodes. They are automatically registered. Status is sent on STDOUT.

Supported: One MAC address per line.

=cut
# TODO support more fields
# TODO instead of printout to STDOUT directly, we should provide a handle to print to in pfcmd
#      this would allow callers to determine where the output should go. pfcmd -> STDOUT, SOAP -> Apache
sub nodes {
    my ($filename) = @_;
    my $logger = Log::Log4perl::get_logger('pf::import');

    my $csv = Text::CSV->new({ binary => 1 });
    open my $io, "<", $filename
        or $logger->logdie("Unable to import from file: $filename. Error: $!");

    # handle first row to validate file format
    $logger->info("Starting node bulk importation");
    my $line = 0;
    my $row = $csv->getline($io);
    if (!valid_mac($row->[0])) {
        close $io;
        $logger->logdie("Nodes import expects first column of first row to be a MAC address. Not processing file.");
    }

    # pre-compute info hash
    my %info = (
        notes => POSIX::strftime("Imported on %Y-%m-%d %H:%M:%S", localtime(time))
    );

    # Assign default values from parameters under [node_import] in pf.conf
    # fancy hash slicing assigns pid to pid, etc.
    @info{qw/pid category voip/} = @{$Config{'node_import'}}{qw/pid category voip/};

    do {
        # setup
        my $mac = $row->[0];
        $line++;

        # is MAC valid?
        if (!valid_mac($mac)) {
            $logger->warn("Problem with entry on line $line MAC $mac: Invalid MAC");
            printf("%04d: %s NOT REGISTERED! MAC not considered valid.\n", $line, $mac);
        } else {

            $mac = clean_mac($mac);
            # TODO time / memory tradeoff by removing already registered node before looping on each MAC
            # should we register the MAC?
            my $node = node_view($mac);
            # if node entry doesn't exist 
            # or if entry is valid and node is not registered 
            if (!defined($node) || (ref($node) eq 'HASH' && $node->{'status'} ne $pf::node::STATUS_REGISTERED)) {
                # try to register
                my $pid = $info{'pid'} || $default_pid;
                if (node_register($mac, $pid, %info)) {
                    printf("%04d: %s registered\n", $line, $mac);
                } else {
                    $logger->warn("Problem with entry on line $line MAC $mac: node_register returned an error");
                    printf("%04d: %s NOT REGISTERED! node registration error. Check logs for details.\n", $line, $mac);
                }
            } else {
                $logger->info("Import $line MAC $mac: node was already registered.");
                printf("%04d: %s already registered, nothing done\n", $line, $mac);
            }
        }

    } while ($row = $csv->getline($io));

    $logger->info("End of node bulk importation");
    close $io;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
