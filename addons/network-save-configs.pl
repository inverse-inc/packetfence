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

=for comment
The section below is synced with our FAQ's page on the packetfence.org website.

Some switches doesn't save MAC addresses in the port-security table to the startup-config automatically when the table is modified.

This means that if you have a power outage the security table needs to be re-created from scratch. 
This is not a problem usually since the appropriate traps will be sent to PacketFence. 
However, if you implement configuration changes while users are connected and in the security table, then you experience power outage and during that window people connect to other equipment, the port-security state on the PacketFence server no longer matches what will be in the original switch of the user after it reboots. 
In that case, saving configs often can insure that the VLAN and port-security configuration will match a recent state that the user is expected to be in.

The network-save-configs.pl (provided in addons/) will crawl through the list of all network devices in conf/switches.conf and it will perform a running-config to startup-config copy (if the device supports saving configuration through SNMP).

You can run the script manually with:

  network-save-configs.pl

Once you are confident it's doing the right thing for you, you can add it to cron

  MAILTO=pf-admins@domain.com 
  12 23 * * * if [ -f /var/run/mysqld/mysqld.pid ]; then /usr/local/pf/addons/network-save-configs.pl -v 0 2>&1; fi

-v 0 makes sure that only FATALs will be emailed to admins and the test on the MySQL file is to make sure that it only runs on the active cluster (if you do high-availability).

The script only supports Cisco switches for now. 
Others switches could be added if they expose configuration saving through SNMP. 
Please let us know if you are interested.

This is not useful for MAC-Authentication or 802.1X-based access control techniques.

=cut
use strict;
use warnings;

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

