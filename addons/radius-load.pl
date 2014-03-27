#!/usr/bin/perl
=head1 NAME

radius-load add documentation

=cut

=head1 DESCRIPTION

radius-load

=head1 SYNOPSIS

    radius-load <options>

     Options:
        --file, -f      the path of the switches.conf file default switches.conf
        --host, -H      the host name of the radius server default localhost
        --port, -p      the port of the radius server.
        --children, -c  the number of children
        --help, -h      brief help message


      Requires the following packages
       Config::IniFiles
       Net::Radius;

=cut

use strict;
use warnings;
use POSIX qw(:sys_wait_h pause);
use Config::IniFiles;
use IO::Socket::INET;
use IO::Select;
use Getopt::Long;
use Net::Radius::Packet;
use Net::Radius::Dictionary;
use Pod::Usage;
use File::Temp qw(tempfile);

our $switches_config_file = 'switches.conf';
our $child_count = 10;
our $help;
our $host = 'localhost';
our $port = 1812;
our $dictionaryFilename;
our $dictionary;
our $timeout = 2;

GetOptions (
    "file|f=s" => \$switches_config_file,
    "host|H=s" => \$host,
    "port|p=s" => \$port,
    "children|c=i"   => \$child_count,
    "help|h"   => \$help,
)  or pod2usage(1);

pod2usage(0) if $help;

createDictionaryFile();

$dictionary = Net::Radius::Dictionary->new($dictionaryFilename);

my $switches_config = Config::IniFiles->new(
    -file         => $switches_config_file,
    -allowempty   => 1,
    -default      => 'default',
);

our @SWITCHES = grep {
    my $result = $_ ne 'default';
    if($result) {
        my $val = $switches_config->val($_,'radiusSecret');
        $result = defined $val && $val !~ /^\s+$/;
    }
    $result;
} $switches_config->Sections();

our %CHILDREN;
our $childPid;
our $currentCount = 0;

our $running = 1;
our $childDied = 0;

$SIG{INT} = $SIG{TERM} = sub {
    $running = 0;
};

sub startChildren {
    while ( $currentCount < $child_count ) {
        my $childPid = fork();
        if($childPid > 0) {
            $currentCount++;
            $CHILDREN{$childPid} = undef;
        } elsif($childPid == 0) {
            sendRadiusRequest();
            exit 0;
        } else {
            killChildren();
            exit 1;
        }
    }
}

$SIG{CHLD} = sub { $childDied = 1; };
startChildren();

while($running) {
    if($childDied) {
        reapChildren();
        startChildren();
        $childDied = 0;
    }
    pause;
}

print "Killing children\n";
killChildren();

while ($currentCount) {
    pause;
    my $killed = reapChildren();
}

sub killChildren {
    return kill 'TERM', keys %CHILDREN;
}

sub reapChildren {
    my $child;
    my $count = 0;
    while(1) {
        $child = waitpid(-1, &POSIX::WNOHANG);
        last unless $child > 0;
        $currentCount--;
        delete $CHILDREN{$child};
        $count++;
    }
    return $count;
}


sub sendRadiusRequest {
    $SIG{ALRM} = sub {};
    while($running) {
        my $switch = $SWITCHES[ int(rand @SWITCHES ) ];
        my $secret = $switches_config->val($switch,'radiusSecret');
        my $mac = sprintf("%02X-%02X-%02X-%02X-%02X-%02X",int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)));
        my $called = uc($switch);
        my ($user,$pass);
        $user = lc($mac);
        $user =~ s/-//g;
        $pass = $user;
        $called =~ s/:/-/g;
        $called .= ":TEST";
        print "Sending request for $mac to switch $switch $called\n";
        perform_dynauth(
            $secret,
            { Name => 'User-Name', Value => $user },
            { Name => 'User-Password', Value => $pass },
            { Name => 'Called-Station-Id', Value => $called },
            { Name => 'Calling-Station-Id', Value => $mac },
            { Name => 'NAS-Port-Type', Value => 19 },
            { Name => 'Connect-Info', Value => "CONNECT 11Mbps 802.11b" },
        );
        alarm(int(rand(2)) + 1);
        pause;
    }
}

sub createDictionaryFile {
    my $fh;
    ($fh, $dictionaryFilename) = tempfile();

    print $fh <<'DICT';

# -*- text -*-
#
#	Attributes and values defined in RFC 2865.
#	http://www.ietf.org/rfc/rfc2865.txt
#
#	$Id$
#
ATTRIBUTE	User-Name				1	string
ATTRIBUTE	User-Password				2	string
ATTRIBUTE	CHAP-Password				3	octets
ATTRIBUTE	NAS-IP-Address				4	ipaddr
ATTRIBUTE	NAS-Port				5	integer
ATTRIBUTE	Service-Type				6	integer
ATTRIBUTE	Framed-Protocol				7	integer
ATTRIBUTE	Framed-IP-Address			8	ipaddr
ATTRIBUTE	Framed-IP-Netmask			9	ipaddr
ATTRIBUTE	Framed-Routing				10	integer
ATTRIBUTE	Filter-Id				11	string
ATTRIBUTE	Framed-MTU				12	integer
ATTRIBUTE	Framed-Compression			13	integer
ATTRIBUTE	Login-IP-Host				14	ipaddr
ATTRIBUTE	Login-Service				15	integer
ATTRIBUTE	Login-TCP-Port				16	integer
# Attribute 17 is undefined
ATTRIBUTE	Reply-Message				18	string
ATTRIBUTE	Callback-Number				19	string
ATTRIBUTE	Callback-Id				20	string
# Attribute 21 is undefined
ATTRIBUTE	Framed-Route				22	string
ATTRIBUTE	Framed-IPX-Network			23	ipaddr
ATTRIBUTE	State					24	octets
ATTRIBUTE	Class					25	octets
ATTRIBUTE	Vendor-Specific				26	octets
ATTRIBUTE	Session-Timeout				27	integer
ATTRIBUTE	Idle-Timeout				28	integer
ATTRIBUTE	Termination-Action			29	integer
ATTRIBUTE	Called-Station-Id			30	string
ATTRIBUTE	Calling-Station-Id			31	string
ATTRIBUTE	NAS-Identifier				32	string
ATTRIBUTE	Proxy-State				33	octets
ATTRIBUTE	Login-LAT-Service			34	string
ATTRIBUTE	Login-LAT-Node				35	string
ATTRIBUTE	Login-LAT-Group				36	octets
ATTRIBUTE	Framed-AppleTalk-Link			37	integer
ATTRIBUTE	Framed-AppleTalk-Network		38	integer
ATTRIBUTE	Framed-AppleTalk-Zone			39	string

ATTRIBUTE	CHAP-Challenge				60	octets
ATTRIBUTE	NAS-Port-Type				61	integer
ATTRIBUTE	Port-Limit				62	integer
ATTRIBUTE	Login-LAT-Port				63	string
ATTRIBUTE   Connect-Info                77  string

#
#	Integer Translations
#

#	Service types

VALUE	Service-Type			Login-User		1
VALUE	Service-Type			Framed-User		2
VALUE	Service-Type			Callback-Login-User	3
VALUE	Service-Type			Callback-Framed-User	4
VALUE	Service-Type			Outbound-User		5
VALUE	Service-Type			Administrative-User	6
VALUE	Service-Type			NAS-Prompt-User		7
VALUE	Service-Type			Authenticate-Only	8
VALUE	Service-Type			Callback-NAS-Prompt	9
VALUE	Service-Type			Call-Check		10
VALUE	Service-Type			Callback-Administrative	11

#	Framed Protocols

VALUE	Framed-Protocol			PPP			1
VALUE	Framed-Protocol			SLIP			2
VALUE	Framed-Protocol			ARAP			3
VALUE	Framed-Protocol			Gandalf-SLML		4
VALUE	Framed-Protocol			Xylogics-IPX-SLIP	5
VALUE	Framed-Protocol			X.75-Synchronous	6

#	Framed Routing Values

VALUE	Framed-Routing			None			0
VALUE	Framed-Routing			Broadcast		1
VALUE	Framed-Routing			Listen			2
VALUE	Framed-Routing			Broadcast-Listen	3

#	Framed Compression Types

VALUE	Framed-Compression		None			0
VALUE	Framed-Compression		Van-Jacobson-TCP-IP	1
VALUE	Framed-Compression		IPX-Header-Compression	2
VALUE	Framed-Compression		Stac-LZS		3

#	Login Services

VALUE	Login-Service			Telnet			0
VALUE	Login-Service			Rlogin			1
VALUE	Login-Service			TCP-Clear		2
VALUE	Login-Service			PortMaster		3
VALUE	Login-Service			LAT			4
VALUE	Login-Service			X25-PAD			5
VALUE	Login-Service			X25-T3POS		6
VALUE	Login-Service			TCP-Clear-Quiet		8

#	Login-TCP-Port		(see /etc/services for more examples)

VALUE	Login-TCP-Port			Telnet			23
VALUE	Login-TCP-Port			Rlogin			513
VALUE	Login-TCP-Port			Rsh			514

#	Termination Options

VALUE	Termination-Action		Default			0
VALUE	Termination-Action		RADIUS-Request		1

#	NAS Port Types

VALUE	NAS-Port-Type			Async			0
VALUE	NAS-Port-Type			Sync			1
VALUE	NAS-Port-Type			ISDN			2
VALUE	NAS-Port-Type			ISDN-V120		3
VALUE	NAS-Port-Type			ISDN-V110		4
VALUE	NAS-Port-Type			Virtual			5
VALUE	NAS-Port-Type			PIAFS			6
VALUE	NAS-Port-Type			HDLC-Clear-Channel	7
VALUE	NAS-Port-Type			X.25			8
VALUE	NAS-Port-Type			X.75			9
VALUE	NAS-Port-Type			G.3-Fax			10
VALUE	NAS-Port-Type			SDSL			11
VALUE	NAS-Port-Type			ADSL-CAP		12
VALUE	NAS-Port-Type			ADSL-DMT		13
VALUE	NAS-Port-Type			IDSL			14
VALUE	NAS-Port-Type			Ethernet		15
VALUE	NAS-Port-Type			xDSL			16
VALUE	NAS-Port-Type			Cable			17
VALUE	NAS-Port-Type			Wireless-Other		18
VALUE	NAS-Port-Type			Wireless-802.11		19


# -*- text -*-
#
#	Attributes and values defined in RFC 2866.
#	http://www.ietf.org/rfc/rfc2866.txt
#
#	$Id$
#
ATTRIBUTE	Acct-Status-Type			40	integer
ATTRIBUTE	Acct-Delay-Time				41	integer
ATTRIBUTE	Acct-Input-Octets			42	integer
ATTRIBUTE	Acct-Output-Octets			43	integer
ATTRIBUTE	Acct-Session-Id				44	string
ATTRIBUTE	Acct-Authentic				45	integer
ATTRIBUTE	Acct-Session-Time			46	integer
ATTRIBUTE	Acct-Input-Packets			47	integer
ATTRIBUTE	Acct-Output-Packets			48	integer
ATTRIBUTE	Acct-Terminate-Cause			49	integer
ATTRIBUTE	Acct-Multi-Session-Id			50	string
ATTRIBUTE	Acct-Link-Count				51	integer

#	Accounting Status Types

VALUE	Acct-Status-Type		Start			1
VALUE	Acct-Status-Type		Stop			2
VALUE	Acct-Status-Type		Alive			3   # dup
VALUE	Acct-Status-Type		Interim-Update		3
VALUE	Acct-Status-Type		Accounting-On		7
VALUE	Acct-Status-Type		Accounting-Off		8
VALUE	Acct-Status-Type		Failed			15

#	Authentication Types

VALUE	Acct-Authentic			RADIUS			1
VALUE	Acct-Authentic			Local			2
VALUE	Acct-Authentic			Remote			3
VALUE	Acct-Authentic			Diameter		4

#	Acct Terminate Causes

VALUE	Acct-Terminate-Cause		User-Request		1
VALUE	Acct-Terminate-Cause		Lost-Carrier		2
VALUE	Acct-Terminate-Cause		Lost-Service		3
VALUE	Acct-Terminate-Cause		Idle-Timeout		4
VALUE	Acct-Terminate-Cause		Session-Timeout		5
VALUE	Acct-Terminate-Cause		Admin-Reset		6
VALUE	Acct-Terminate-Cause		Admin-Reboot		7
VALUE	Acct-Terminate-Cause		Port-Error		8
VALUE	Acct-Terminate-Cause		NAS-Error		9
VALUE	Acct-Terminate-Cause		NAS-Request		10
VALUE	Acct-Terminate-Cause		NAS-Reboot		11
VALUE	Acct-Terminate-Cause		Port-Unneeded		12
VALUE	Acct-Terminate-Cause		Port-Preempted		13
VALUE	Acct-Terminate-Cause		Port-Suspended		14
VALUE	Acct-Terminate-Cause		Service-Unavailable	15
VALUE	Acct-Terminate-Cause		Callback		16
VALUE	Acct-Terminate-Cause		User-Error		17
VALUE	Acct-Terminate-Cause		Host-Request		18



# -*- text -*-
#
#	Attributes and values defined in RFC 3576.
#	http://www.ietf.org/rfc/rfc3576.txt
#
#	$Id$
#
ATTRIBUTE	Error-Cause				101	integer

#	Service Types

VALUE	Service-Type			Authorize-Only		17

#	Error causes

VALUE	Error-Cause			Residual-Context-Removed 201
VALUE	Error-Cause			Invalid-EAP-Packet	202
VALUE	Error-Cause			Unsupported-Attribute	401
VALUE	Error-Cause			Missing-Attribute	402
VALUE	Error-Cause			NAS-Identification-Mismatch 403
VALUE	Error-Cause			Invalid-Request		404
VALUE	Error-Cause			Unsupported-Service	405
VALUE	Error-Cause			Unsupported-Extension	406
VALUE	Error-Cause			Administratively-Prohibited 501
VALUE	Error-Cause			Proxy-Request-Not-Routable 502
VALUE	Error-Cause			Session-Context-Not-Found 503
VALUE	Error-Cause			Session-Context-Not-Removable 504
VALUE	Error-Cause			Proxy-Processing-Error	505
VALUE	Error-Cause			Resources-Unavailable	506
VALUE	Error-Cause			Request-Initiated	507

# -*- text -*-
#
# dictionary.cisco
#
#               Accounting VSAs originally by
#               "Marcelo M. Sosa Lugones" <marcelo@sosa.com.ar>
#
# Version:      $Id$
#
#  For documentation on Cisco RADIUS attributes, see:
#
# http://www.cisco.com/univercd/cc/td/doc/product/access/acs_serv/vapp_dev/vsaig3.htm
#
#  For general documentation on Cisco RADIUS configuration, see:
#
# http://www.cisco.com/en/US/partner/tech/tk583/tk547/tsd_technology_support_sub-protocol_home.html
#

VENDOR          Cisco                           9

#
#       Standard attribute
#

VENDORATTR      Cisco                           Cisco-AVPair    1       string
VENDORATTR      Cisco                           Cisco-NAS-Port  2       string


DICT

    close($fh);

}

END {
    unlink($dictionaryFilename) if defined $dictionaryFilename && -e $dictionaryFilename;
}

sub perform_dynauth {
    my ($secret,@attributes) = @_;

    # setting up defaults

    # Warning: original code had Reuse => 1 (Note: Reuse is deprecated in favor of ReuseAddr)
    my $socket = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto => 'udp',
    ) or die ("Couldn't create UDP connection: $@");

    my $radius_request = Net::Radius::Packet->new($dictionary);
    $radius_request->set_code('Access-Request');
    # sets a random byte into id
    $radius_request->set_identifier( int(rand(256)) );
    # avoids unnecessary warnings
    $radius_request->set_authenticator("");

    # pushing attributes
    # TODO deal with attribute merging
    foreach my $attr (@attributes) {
        next unless defined $attr->{Value};
        $radius_request->set_attr($attr->{Name}, $attr->{Value});
    }

    # Warning: untested
    # TODO deal with attribute merging

    # applying shared-secret signing then send
    $socket->send(auth_resp($radius_request->pack(), $secret));

    # Listen for the response.
    # Using IO::Select because otherwise we can't do timeout without using alarm()
    # and signals don't play nice with threads
    my $select = IO::Select->new($socket);
    while (1) {
        if ($select->can_read($timeout)) {

            my $rad_data;
            my $MAX_TO_READ = 2048;
            return undef
                if (!$socket->recv($rad_data, $MAX_TO_READ));

            my $radius_reply = Net::Radius::Packet->new($dictionary, $rad_data);
            # identifies if the reply is related to the request? damn you udp...
            if ($radius_reply->identifier() != $radius_request->identifier()) {
                die("Received an invalid RADIUS packet identifier: " . $radius_reply->identifier());
            }

            my %return = ( 'Code' => $radius_reply->code() );
            # TODO deal with attribute merging
            # TODO deal with vsa attributes merging
            foreach my $key ($radius_reply->attributes()) {
                $return{$key} = $radius_reply->attr($key);
            }
            return \%return;

        } else {
            return undef;
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

