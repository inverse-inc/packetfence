#!/usr/bin/perl -w

=head1 NAME

convertToPortSecurity.pl - convert to port security

=head1 SYNOPSIS

convertToPortSecurity.pl [options]

 Command:
   -help           brief help message
   -man            full documentation

 Options:
   -backupconfig   backup file for current switch config
   -switch         switch IP to connect to
   -snmpserver     SNMP server IP
   -verbose        log verbosity level
                     0 : fatal messages
                     1 : warn messages
                     2 : info messages
                   > 2 : full debug


=head1 DESCRIPTION

This script connects to a specified switch and converts to
port security.

=cut

use strict;
use warnings;

use FindBin;

use constant {
    LIB_DIR   => $FindBin::Bin . "/../lib",
    CONF_FILE => $FindBin::Bin . "/../conf/switches.conf",
};

use lib LIB_DIR;

use Getopt::Long;
use Pod::Usage;
use Net::SNMP;
use Net::Appliance::Session;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use DBI;

use pf::SwitchFactory;
use pf::config;
use pf::db;
use pf::node;
use pf::locationlog;

my $help;
my $man;
my $logLevel = 2;
my $switch_ip;
my $backup_config;
my $doit;
my $snmp_server;

GetOptions(
    "help|?"         => \$help,
    "man"            => \$man,
    "switch:s"       => \$switch_ip,
    "backupconfig:s" => \$backup_config,
    "snmpserver:s"   => \$snmp_server,
    "imsure"         => \$doit,
    "verbose:i"      => \$logLevel
) or pod2usage( -verbose => 1 );

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;

pod2usage( -verbose => 1 ) if ( !$switch_ip );
pod2usage( -verbose => 1 ) if ( !$backup_config );
pod2usage( -verbose => 1 ) if ( !$snmp_server );

if ( $logLevel == 0 ) {
    $logLevel = $FATAL;
} elsif ( $logLevel == 1 ) {
    $logLevel = $WARN;
} elsif ( $logLevel == 2 ) {
    $logLevel = $INFO;
} else {
    $logLevel = $DEBUG;
}
Log::Log4perl->easy_init(
    {   level  => $logLevel,
        layout => '%d   %m %n'
    }
);
my $logger = Log::Log4perl->get_logger('');

my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE );

my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';

if ( !exists( $switchFactory->{_config}{$switch_ip} ) ) {
    $logger->logdie("switch $switch_ip not found in switch.conf");
}

my $switchType = $switchFactory->{_config}{$switch_ip}{'type'};
if (!(  $switchType
        =~ /Cisco::Catalyst_29(50|60|70)|Cisco::Catalyst_35(50|60)/
    )
    )
{
    $logger->logdie("port security is not supported on $switchType");
}

my $backup_fh;
open $backup_fh, '>', "$backup_config"
    or $logger->logdie("can't open config backup file $backup_config");

$logger->debug("instantiating switch object");
my $switch = $switchFactory->instantiate($switch_ip);
if (!$switch) {
    $logger->logdie("Can not instantiate switch $switch_ip");
}

if ( !$switch->connectRead() ) {
    $logger->logdie("unable to connect");
}

#obtain all ifIndexes
$logger->debug("obtaining ifDesc for all ifIndexes");
my $ifDescHashRef;
my $result = $switch->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
foreach my $key ( keys %{$result} ) {
    my $ifDesc = $result->{$key};
    if ( $ifDesc =~ /ethernet/i ) {
        $key =~ /^$OID_ifDesc\.(\d+)$/;
        my $ifIndex = $1;
        $ifDescHashRef->{$ifIndex} = $ifDesc;
    }
}

#connect to switch
$logger->debug( "instantiating " . $switch->{_cliTransport} . " session" );
my $session;
eval {
    $session = Net::Appliance::Session->new(
        Host      => $switch->{_ip},
        Timeout   => 5,
        Transport => $switch->{_cliTransport}
    );
    $session->connect(
        Name     => $switch->{_cliUser},
        Password => $switch->{_cliPwd}
    );
};
if ($@) {
    $logger->logdie( "Can not connect to switch $switch->{'_ip'} using "
            . $switch->{_cliTransport} );
}
# Session not already privileged are not supported at this point. See #1370
#if ( !$session->in_privileged_mode() ) {
#    if ( !$session->begin_privileged( $switch->{_cliEnablePwd} ) ) {
#        $logger->logdie("Can not enable");
#    }
#}

#obtain current config
$logger->debug("obtaining current config");

my @tmp = $session->cmd("show run | include snmp-server");
if ( grep( {/snmp-server enable traps port-security$/i} @tmp ) > 0 ) {
    $logger->debug("snmp-server enable traps port-security alread present");
} else {
    $logger->info(
        "adding 'snmp-server enable traps port-security' to switch config");
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("snmp-server enable traps port-security");
        $session->cmd("end");
    }
}
if (grep( {/^snmp-server enable traps port-security trap-rate 1$/i} @tmp )
    > 0 )
{
    $logger->debug(
        "snmp-server enable traps port-security trap rate alread present");
} else {
    $logger->info(
        "adding 'snmp-server enable traps port-security trap-rate 1' to switch config"
    );
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("snmp-server enable traps port-security trap-rate 1");
        $session->cmd("end");
    }
}
if ( grep( {/^snmp-server host $snmp_server .+ port-security/i} @tmp ) > 0 ) {
    $logger->debug("snmp-server host port-security alread present");
} else {
    $logger->info(
        "adding 'snmp-server host $snmp_server version 2c public port-security' to switch config"
    );
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd(
            "snmp-server host $snmp_server version 2c public port-security");
        $session->cmd("end");
    }
}

my @uplinks = $switch->getUpLinks();
foreach my $ifIndex ( sort { $a <=> $b } keys %$ifDescHashRef ) {
    my $ifDesc = $ifDescHashRef->{$ifIndex};
    my @tmp    = $session->cmd("show run interface $ifDesc");
    my $config = '';
    my $lineNb = 0;
    while (( $lineNb < scalar(@tmp) )
        && ( !( $tmp[$lineNb] =~ /^interface / ) ) )
    {
        $lineNb++;
    }
    while ( $lineNb < scalar(@tmp) ) {
        if ( !( $tmp[$lineNb] =~ /^\s*$/ ) ) {
            $config .= $tmp[$lineNb];
        }
        $lineNb++;
    }

    #exclude some ports:
    if ( grep( {/^$ifIndex$/} @uplinks ) > 0 ) {
        $logger->info("ifIndex $ifIndex excluded since defined as uplink");
    } elsif ( ( $config =~ /switchport access vlan (\d+)/i )
        && ( grep( {/^$1$/} @{ $switch->{_vlans} } ) == 0 ) )
    {
        $logger->info(
            "ifIndex $ifIndex excluded since access VLAN $1 is not a managed VLAN"
        );
    } elsif ( $config =~ /switchport mode trunk/i ) {
        $logger->info("ifIndex $ifIndex excluded since trunk");
    } elsif ( $config =~ /switchport port-security/i ) {
        $logger->info(
            "ifIndex $ifIndex excluded since port security is already configured"
        );
    } else {
        my @macArray = $switch->_getMacAtIfIndex($ifIndex);
        if ( scalar(@macArray) > 1 ) {
            $logger->info(
                "ifIndex $ifIndex excluded since several MACs are present");
        } else {
            my $macToSecure;
            if ( scalar(@macArray) == 1 ) {
                $macToSecure = $macArray[0];
                if ( !node_exist($macToSecure) ) {
                    $logger->info(
                        "node $macToSecure is a new node. Adding it to node table"
                    );
                    if ($doit) {
                        node_add_simple($macToSecure);
                    }
                }
            } else {
                $macToSecure
                    = "02:00:00:00:00:"
                    . ( ( length($ifIndex) == 1 )
                    ? "0" . substr( $ifIndex, -1, 1 )
                    : substr( $ifIndex, -2, 2 ) );
            }
            print {$backup_fh} $config;
            $logger->debug("current switchport config is:\n$config");
            my @modLines;
            if ( $config =~ /snmp trap mac-notification added/ ) {
                push @modLines, "no snmp trap mac-notification added";
            }
            if ( $macToSecure =~ /02:00:00:00:00/ ) {
                push @modLines,
                    "switchport access vlan " . $switch->{_macDetectionVlan};
            } else {
                # TODO: we should provide a flag to offer either setting vlan by node or by switch
                if ( $config =~ /switchport access vlan dynamic/ ) {
                    my $node_info = node_view($macToSecure);
                    if ( $node_info->{'bypass_vlan'} ne '' ) {
                        push @modLines,
                            "switchport access vlan " . $node_info->{'bypass_vlan'};
                    } else {
                        push @modLines, "switchport access vlan "
                            . $switch->{_normalVlan};
                    }
                }
            }
            push @modLines, "switchport port-security";
            push @modLines, "no switchport port-security";
            push @modLines, "switchport port-security mac-address "
                . convertMac($macToSecure);
            push @modLines, "switchport port-security";
            if ( !( $switchType =~ /Cisco::Catalyst_(29|35)50/ ) ) {
                push @modLines,
                    "switchport port-security maximum 1 vlan access";
            }
            push @modLines, "switchport port-security violation restrict";
            $logger->debug( "switchport configuration command lines:\n"
                    . join( "\n", @modLines ) );
            if ($doit) {
                $logger->info(
                    "securing MAC $macToSecure on ifIndex $ifIndex");
                print Dumper( $session->cmd("conf t") );
                print Dumper( $session->cmd("interface $ifDesc") );
                foreach my $modLine (@modLines) {
                    print $modLine . "\n";
                    print Dumper( $session->cmd($modLine) );
                }
                print Dumper( $session->cmd("end") );
                $logger->debug("synchronizing locationlog entries");
                if ( !( $macToSecure =~ /02:00:00:00:00/ ) ) {
                    locationlog_synchronize( $switch_ip, $ifIndex,
                        $switch->getVlan($ifIndex), $macToSecure, $NO_VOIP, $WIRED_SNMP_TRAPS);
                }
            }
        }
    }
}

close $backup_fh;

@tmp = $session->cmd("show run | include snmp-server");
if ( grep( {/snmp-server enable traps mac-notification$/i} @tmp ) > 0 ) {
    $logger->debug("snmp-server enable traps mac-notification still present");
    $logger->info(
        "removing 'snmp-server enable traps mac-notification' from switch config"
    );
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("no snmp-server enable traps mac-notification");
        $session->cmd("end");
    }
}
if ( grep( {/snmp-server enable traps snmp.+linkdown/i} @tmp ) > 0 ) {
    $logger->debug("snmp-server enable traps snmp linkdown still present");
    $logger->info(
        "removing 'snmp-server enable traps snmp linkdown' from switch config"
    );
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("no snmp-server enable traps snmp linkdown");
        $session->cmd("end");
    }
}
if ( grep( {/snmp-server enable traps snmp.+linkup/i} @tmp ) > 0 ) {
    $logger->debug("snmp-server enable traps snmp linkup still present");
    $logger->info(
        "removing 'snmp-server enable traps snmp linkup' from switch config");
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("no snmp-server enable traps snmp linkup");
        $session->cmd("end");
    }
}

@tmp = $session->cmd("show run | include mac-address-table");
if ( grep( {/mac-address-table notification interval 0$/i} @tmp ) > 0 ) {
    $logger->debug("mac-address-table notification interval 0 still present");
    $logger->info(
        "removing 'mac-address-table notification interval 0' from switch config"
    );
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("no mac-address-table notification interval 0");
        $session->cmd("end");
    }
}
if ( grep( {/mac-address-table notification$/i} @tmp ) > 0 ) {
    $logger->debug("mac-address-table notification still present");
    $logger->info(
        "removing 'mac-address-table notification' from switch config");
    if ($doit) {
        $session->cmd("conf t");
        $session->cmd("no mac-address-table notification");
        $session->cmd("end");
    }
}

$session->close();

sub convertMac {
    my ($temp) = @_;
    return
          substr( $temp, 0, 2 )
        . substr( $temp, 3,  2 ) . "."
        . substr( $temp, 6,  2 )
        . substr( $temp, 9,  2 ) . "."
        . substr( $temp, 12, 2 )
        . substr( $temp, 15, 2 );
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

