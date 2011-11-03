#!/usr/bin/perl -w

=head1 NAME

network-save-configs.pl - connect to all network devices and save configuration

=head1 SYNOPSIS

network-save-configs.pl [options]

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

Will save the running configuration in startup configuration if the network device supports the capability.
Currently we don't support many but support could be added if requested.

=cut
use strict;
use warnings;
use diagnostics;

use FindBin;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;
use threads;
use Try::Tiny;

use constant {
    INSTALL_DIR => $FindBin::Bin . '/..',
    LIB_DIR     => $FindBin::Bin . "/../lib",
    CONF_FILE   => $FindBin::Bin . "/../conf/switches.conf",
};

use lib LIB_DIR;

use pf::SwitchFactory;

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
Log::Log4perl->easy_init({ level  => $logLevel, layout => '%p: %m (%rms elapsed)%n' });
my $logger = Log::Log4perl->get_logger('');

my $networkDeviceFactory = new pf::SwitchFactory( -configFile => CONF_FILE );

my %Config = %{ $networkDeviceFactory->{_config} };

foreach my $network_device_ip ( sort keys %Config ) {
    next if ($network_device_ip eq 'default');
    next if ($network_device_ip eq '127.0.0.1');

    my $networkDevice = $networkDeviceFactory->instantiate($network_device_ip);

    if (!$networkDevice) {
        $logger->error("[$network_device_ip] Can't instantiate network device!");
        next;
    }

    $logger->debug("Working on [$network_device_ip]...");
    try {
        if ($networkDevice->supportsSaveConfig()) {
            if ($networkDevice->saveConfig()) {
                $logger->info("[$network_device_ip] Configuration successfully saved!");
            } else {
                $logger->fatal("[$network_device_ip] Saving configuration failed!");
            }
        } else {
            $logger->debug("[$network_device_ip] doesn't support saving configuration.");
        }
    } catch {
        chomp($_);
        $logger->fatal("[$network_device_ip] error: $_");
    }
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

