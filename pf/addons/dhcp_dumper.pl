#!/usr/bin/perl 

=head1 NAME

dhcp_dumper.pl - listen to DHCP packets

=head1 SYNOPSIS

dhcp_dumper.pl [options]

 Options:
   -i      Interface (eg. "eth0")
   -f      Filter (eg. "host 128.103.1.1")
   -c      CHADDR (show requests from specific client)
   -t      DHCP message type
             Value   Message Type
             -----   ------------
               1     DHCPDISCOVER
               2     DHCPOFFER
               3     DHCPREQUEST
               4     DHCPDECLINE
               5     DHCPACK
               6     DHCPNAK
               7     DHCPRELEASE
               8     DHCPINFORM
   -u      Only show packets with unknown DHCP prints
   -v      verbose 
   -h      Help

=cut
use strict;
use warnings;

use Config::IniFiles;
use File::Basename qw(basename);
use FindBin;
use Getopt::Std;
use Log::Log4perl qw(:easy);
use Net::Pcap 0.16;
use Pod::Usage;

use lib $FindBin::Bin . "/../lib";

use pf::util;

my %args;
getopts( 't:i:f:c:o:huv', \%args );

my $interface = $args{i} || "eth0";

if ( $args{h} || !$interface ) {
    pod2usage( -verbose => 1 );
}

my $chaddr_filter;
if ( $args{c} ) {
    $chaddr_filter = clean_mac( $args{c} );
}
my $filter = "(udp and (port 67 or port 68))";
if ( $args{f} ) {
    $filter .= " and " . $args{f};
}
my $type;
if ( $args{t} ) {
    $type = $args{t};
}
my $unknown;
if ( $args{u} ) {
    $unknown = 1;
}
my $verbose = $INFO;
if ( $args{v} ) {
    $verbose = $DEBUG;
}
Log::Log4perl->easy_init({ level  => $verbose, layout => '%m%n' });
my $logger = Log::Log4perl->get_logger('');                                                                             

my $prints_file;
my %prints;
if ( $args{o} ) {
    $prints_file = $args{o};
} else {
    $prints_file = "$FindBin::Bin/../conf/dhcp_fingerprints.conf";
}

if ( -r $prints_file ) {
    my %prints_ini;
    tie %prints_ini, 'Config::IniFiles', ( -file => $prints_file );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        die( "Error reading $prints_file: " 
             . join( "\n", @errors ) . "\n" );
    }

    foreach my $os ( tied(%prints_ini)->GroupMembers("os") ) {
        if ( exists( $prints_ini{$os}{'fingerprints'} ) ) {
            if ( ref( $prints_ini{$os}{'fingerprints'} ) eq "ARRAY" ) {
                foreach my $print ( @{ $prints_ini{$os}{'fingerprints'} } ) {
                    $prints{$print} = $prints_ini{$os}{'description'};
                }
            } else {
                foreach my $print (
                    split( /\n/, $prints_ini{$os}{'fingerprints'} ) ) {
                        $prints{$print} = $prints_ini{$os}{'description'};
                }
            }
        }
    }
}

my %msg_types;
$msg_types{'1'}   = "subnet mask";
$msg_types{'3'}   = "router";
$msg_types{'4'}   = "time server";
$msg_types{'6'}   = "dns servers";
$msg_types{'12'}  = "hostname";
$msg_types{'15'}  = "domain";
$msg_types{'23'}  = "default ttl";
$msg_types{'28'}  = "broadcast";
$msg_types{'31'}  = "router discovery";
$msg_types{'43'}  = "vendor specific information (43)";
$msg_types{'44'}  = "netbios nameserver";
$msg_types{'46'}  = "netbios node type";
$msg_types{'50'}  = "requested ip address";
$msg_types{'51'}  = "address time";
$msg_types{'53'}  = "message type";
$msg_types{'54'}  = "dhcp server id";
$msg_types{'55'}  = "requested parameter list";
$msg_types{'57'}  = "dhcp max message size";
$msg_types{'58'}  = "renewal time";
$msg_types{'59'}  = "rebinding time";
$msg_types{'60'}  = "vendor id";
$msg_types{'61'}  = "client id";
$msg_types{'66'}  = "servername";
$msg_types{'67'}  = "bootfile";
$msg_types{'81'}  = "fqdn";
$msg_types{'82'}  = "agent information (82)";
$msg_types{'150'} = "cisco tftp server (150)";
$msg_types{'116'} = "dhcp auto-config";

my $filter_t;
my $net;
my $mask;
my $opt = 1;
my $err;
my $pcap_t = Net::Pcap::pcap_open_live( $interface, 576, 1, 0, \$err );
if ( ( Net::Pcap::compile( $pcap_t, \$filter_t, $filter, $opt, 0 ) ) == -1 ) {
    $logger->logdie("Unable to compile filter string '$filter'");
}
Net::Pcap::setfilter( $pcap_t, $filter_t );
$logger->info("Starting to listen on $interface with filter: $filter");
Net::Pcap::loop( $pcap_t, -1, \&process_pkt, $interface );

sub process_pkt {
    my ( $user_data, $hdr, $pkt ) = @_;
    listen_dhcp( $pkt, $user_data );
}

sub listen_dhcp {
    my ( $packet, $eth ) = @_;
    $logger->debug("Received packet on interface");

    # decode src/dst MAC addrs
    my ( $dmac, $smac ) = unpack( 'H12H12', $packet );
    $smac = clean_mac($smac);
    $dmac = clean_mac($dmac);

    #return if (!valid_mac($smac));

    # decode IP datagram
    my ($version, $tos,   $length, $id,    $flags,
        $ttl,     $proto, $chksum, $saddr, $daddr
    ) = unpack( 'CCnnnCCnNN', substr( $packet, 14 ) );
    my $ihl = $version & oct(17);
    $version >>= 4;
    my $src = int2ip($saddr);
    my $dst = int2ip($daddr);

    # decode UDP datagram
    my ( $sport, $dport, $len, $udpsum )
        = unpack( 'nnnn', substr( $packet, 14 + $ihl * 4 ) );

    # decode DHCP data
    my ($op,     $htype,  $hlen,   $hops,   $xid,
        $secs,   $dflags, $ciaddr, $yiaddr, $siaddr,
        $giaddr, $chaddr, $sname,  $file,   @options
        )
        = unpack( 'CCCCNnnNNNNH32A64A128C*',
        substr( $packet, 14 + $ihl * 4 + 8 ) );

    $chaddr = clean_mac( substr( $chaddr, 0, 12 ) );
    $ciaddr = int2ip($ciaddr);
    $giaddr = int2ip($giaddr);
    return if ( $chaddr_filter && $chaddr_filter ne $chaddr );

    # decode DHCP options
    # valid DHCP options field begins with 99,130,83,99...
    if ( !join( ":", splice( @options, 0, 4 ) ) =~ /^99:130:83:99$/ ) {
        $logger->warn("invalid DHCP options received from $chaddr");
        return;
    }

    # populate hash with DHCP options
    # ASCII-ify textual data and treat option 55 (parameter list) as an array
    my %options;
    while (@options) {
        my $code = shift(@options);
        push( @{ $options{'options'} }, $code );

        my $length = shift(@options);
        if ( $code != 0 ) {
            while ($length) {
                my $val = shift(@options);
                if (   $code == 15
                    || $code == 12
                    || $code == 60
                    || $code == 66
                    || $code == 67
                    || $code == 81
                    || $code == 4 )
                {
                    if ( $val != 0 && $val != 1 ) {
                        $val = chr($val);
                    } else {
                        $length--;
                        next;
                    }
                }
                push( @{ $options{$code} }, $val );
                $length--;
            }
        }
    }

    # opcode 1 = request, opcode 2 = reply

    #           Value   Message Type
    #           -----   ------------
    #             1     DHCPDISCOVER
    #             2     DHCPOFFER
    #             3     DHCPREQUEST
    #             4     DHCPDECLINE
    #             5     DHCPACK
    #             6     DHCPNAK
    #             7     DHCPRELEASE
    #             8     DHCPINFORM

    if ( !$options{'53'}[0] ) {
        return;
    }
    if ($type) {
        return if ( $type ne $options{'53'}[0] );
    }

    if ( $op == 2 ) {
        if ( $options{'53'}[0] == 2 ) {
            $logger->info("DHCPOFFER from $src ($smac)");
        } elsif ( $options{'53'}[0] == 5 ) {
            $logger->info("DHCPACK received for $ciaddr ($chaddr) XID: $xid");
        }
    } elsif ( $op == 1 ) {
        if ( $options{'53'}[0] == 1 ) {
            my $msg = "DHCPDISCOVER from $chaddr";
            if ($giaddr) {
                $msg .= ", relayed via $giaddr";
            }
            $logger->info($msg);
        } elsif ( $options{'53'}[0] == 3 ) {
            my $msg = "DHCPREQUEST from $ciaddr ($chaddr)";
            if ($giaddr) {
                $msg .= ", relayed via $giaddr";
            }
            $logger->info($msg);
        } elsif ( $options{'53'}[0] == 8 ) {
            my $msg = "DHCPINFORM from $ciaddr ($chaddr)";
            if ($giaddr) {
                $msg .= ", relayed via $giaddr";
            }
            $logger->info($msg);
            return;
        }

        if ( defined( $options{'82'} ) ) {

            my %option_82;
            while ( @{ $options{'82'} } ) {
                my $subopt = shift( @{ $options{'82'} } );

# this makes offset assumptions we probably shouldn't, but it should work fine for Cisco
# assume all cidtype/ridtype always == 0
                shift( @{ $options{'82'} } );
                shift( @{ $options{'82'} } );
                my $len = shift( @{ $options{'82'} } );
                while ($len) {
                    my $val = shift( @{ $options{'82'} } );
                    push( @{ $option_82{$subopt} }, $val );
                    $len--;
                }

            }

            if ( defined( $option_82{'1'} )
                && scalar( @{ $option_82{'1'} } ) )
            {
                my ( $vlan, $mod, $port )
                    = unpack( 'nCC', pack( "C*", @{ $option_82{'1'} } ) );
                my $switch = '';
                $switch = clean_mac(
                    join( ":",
                        unpack( "H*", pack( "C*", @{ $option_82{'2'} } ) ) )
                ) if ( defined( $option_82{'2'} ) );
                delete( $options{'82'} );
                push @{ $options{'82'} },
                      "port " 
                    . $mod . '/' 
                    . $port
                    . " (VLAN $vlan) on switch $switch";
            }
        }
    } else {
        $logger->info("unrecognized DHCP opcode from $chaddr: $op");
    }

    my $print;
    if ( defined( $options{'55'} ) ) {
        $print = join( ",", @{ $options{'55'} } );
        if ( $unknown && defined( $prints{$print} ) ) {
            return;
        }
    } else {
        return;
    }

    foreach my $key ( keys(%options) ) {
        my $tmpkey = $key;
        $tmpkey = $msg_types{$key} if ( defined( $msg_types{$key} ) );
        $logger->info( "$tmpkey: " . join( ",", @{ $options{$key} } ) );
    }

    $logger->info("operating system: $prints{$print}")
        if ( defined( $prints{$print} ) );
    $logger->info("ttl: $ttl");
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2011 Inverse inc.

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

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

