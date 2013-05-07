#!/usr/bin/perl -w

=head1 NAME

update-all-useragents.pl - update all node's User-Agent strings into PF's new 2.2.0 User-Agent features

=head1 SYNOPSIS

update-all-useragents.pl [options]

 Command:
   -help           brief help message
   -man            full documentation

 Options:
   -verbose        log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                     3 : debug
                    >3 : trace


=head1 DESCRIPTION

Update all node's User-Agent strings into PF's new 2.2.0 User-Agent features

Useful for people migrating to 2.2.0 and wants to see if they have Unknown User-Agents in their current nodes.

Running this script when upgrading to 2.2.0 is *not* mandatory.

=cut
use strict;
use warnings;

use FindBin;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;

use constant {
    INSTALL_DIR => '/usr/local/pf',
    LIB_DIR     => $FindBin::Bin . "/../../lib",
};

use lib LIB_DIR;

use pf::config;
use pf::node;
use pf::useragent;

my $help;
my $man;
my $logLevel = 2;

GetOptions(
    "help|?"    => \$help,
    "man"       => \$man,
    "verbose:i" => \$logLevel
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;

if ( $logLevel == 0 ) {
    $logLevel = $FATAL;
} elsif ( $logLevel == 1 ) {
    $logLevel = $WARN;
} elsif ( $logLevel == 2 ) {
    $logLevel = $INFO;
} elsif ( $logLevel == 3 ) {
    $logLevel = $DEBUG;
} else {
    $logLevel = $TRACE;
}
Log::Log4perl->easy_init(
    {   level  => $logLevel,
        layout => '%d %p: %m%n'
    }
);

my $logger = Log::Log4perl->get_logger('');

my $browserDetect = HTTP::BrowserDetect->new();
$logger->info("About to start processing all node's User-Agents");
my $progress = 0;
foreach my $node (node_view_all()) {

    my $mac = $node->{'mac'};
    my $useragent = $node->{'user_agent'};
    $logger->debug("Processing node $mac");

    $browserDetect->user_agent($useragent);
    pf::useragent::update_node_useragent_record($mac, $browserDetect);

    $progress++;
    $logger->info("1000 more done") if ($progress % 1000 == 0);
}
$logger->info("Completed.");

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

