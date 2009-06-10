#!/usr/bin/perl -w

=head1 NAME

configurator.pl - configure PacketFence

=head1 USAGE

  cd /usr/local/pf && ./configurator.pl

Then answer the questions ...

=head1 DESCRIPTION

configurator.pl will help you configure 
F</usr/local/pf/conf/pf.conf> according to your needs. In
particular, it tries to achieve the following tasks:

=over

=item * choice between template and custom configuration

=item * choice of isolation mode (C<arp>, C<dhcp> or C<vlan>)

=item * database connection parameters

=item * hostname and IP address

=item * network configuration (management interfaces)

=back

=head1 DEPENDENCIES

=over

=item * Carp

=item * Config::IniFiles

=item * FindBin

=item * Net::Netmask

=back

=cut

use strict;
use warnings;
use diagnostics;

use FindBin;
use Config::IniFiles;
use Net::Netmask;
use Carp;

my $install_dir = $FindBin::Bin;
my $conf_dir    = "$install_dir/conf";

# check if user is root
die("you must be root!\n") if ( $< != 0 );

my ( %default_cfg, %cfg, %doc, %violation, $upgrade, $template );

tie %default_cfg, 'Config::IniFiles',
    ( -file => "$conf_dir/pf.conf.defaults" )
    or die "Invalid template: $!\n";
tie %doc, 'Config::IniFiles', ( -file => "$conf_dir/documentation.conf" )
    or die "Invalid docs: $!\n";
tie %violation, 'Config::IniFiles', ( -file => "$conf_dir/violations.conf" )
    or die "Invalid violations: $!\n";

# upgrade
print "Checking existing configuration...\n";
if ( -e "$conf_dir/pf.conf" ) {
    $upgrade = 1;
    print "Existing configuration found, upgrading\n";
    tie %cfg, 'Config::IniFiles', ( -file => "$conf_dir/pf.conf" )
        or die "Unable to open existing configuration: $!";
    if ( defined $cfg{'registration'}{'authentication'} ) {
        $cfg{'registration'}{'auth'} = $cfg{'registration'}{'authentication'};
        delete $cfg{'registration'}{'authentication'};
    }

    #config_upgrade();
    write_changes()
        if (
        questioner(
            'Would you like to modify the existing configuration',
            'n', ( 'y', 'n' )
        )
        );

} else {
    print "No existing configuration found\n";
    tie %cfg, 'Config::IniFiles', ( -import => tied(%default_cfg) );
    tied(%cfg)->SetFileName("$conf_dir/pf.conf");
}

# template configuration or custom?
if (questioner(
        'Would you like to use a template configuration or custom',
        't', ( 't', 'c' )
    )
    )
{
    my $template_txt = << "END_TEMPLATE_TXT";
Which template would you like:
                        1) Test mode
                        2) Registration
                        3) Detection
                        4) Registration & Detection
                        5) Registration, Detection & Scanning
                        6) Session-based Authentication
                        7) Registration, Detection and VLAN isolation
                        8) PacketFence ZEN with VLAN isolation
END_TEMPLATE_TXT
    my $type = questioner( $template_txt, '', (1 .. 8) );
    load_template($type);
    print
        "Loading Template: Warning PacketFence is going LIVE - WEAPONS HOT \n"
        if ( $type ne '1' );
    if ( $type ne '1' && $type ne '2' && $type ne '8' ) {
        print
            "Enabling host trapping!  Please make sure to review conf/violations.conf and disable any violations that don't fit your environment\n";
        $violation{defaults}{actions} = "trap,email,log";
        tied(%violation)->WriteConfig("$conf_dir/violations.conf")
            || die "Unable to commit settings: $!\n";
    }
    $template = 1;
}

configuration();
write_changes();

# write and exit
sub write_changes {
    my $port = $default_cfg{'ports'}{'admin'};
    $port = $cfg{'ports'}{'admin'} if ( defined $cfg{'ports'}{'admin'} );
    print
        "Please review conf/pf.conf to correct any errors or change pathing to daemons\n";
    print
        "After starting PF, use bin/pfcmd or the web interface (https://$cfg{'general'}{'hostname'}.$cfg{'general'}{'domain'}:$port) to administer the system\n";
    foreach my $section ( tied(%cfg)->Sections ) {
        next if ( !exists( $default_cfg{$section} ) );
        foreach my $key ( keys( %{ $cfg{$section} } ) ) {
            next if ( !exists( $default_cfg{$section}{$key} ) );
            if ( $cfg{$section}{$key} =~ /$default_cfg{$section}{$key}/i ) {
                delete $cfg{$section}{$key};
                tied(%cfg)->DeleteParameterComment( $section, $key );
            }
        }
    }
    foreach my $section ( tied(%cfg)->Sections ) {
        delete $cfg{$section}
            if ( scalar( keys( %{ $cfg{$section} } ) ) == 0 );
    }

    # IP Bug fix
    foreach my $net ( get_networkinfo() ) {
        my $int = $net->{device};
        if ( defined $cfg{"interface $int"} ) {
            my $ip = $net->{ip};
            $cfg{"interface $int"}{'ip'} = $ip;
        }
    }

    print "Committing settings...\n";
    tied(%cfg)->WriteConfig("$conf_dir/pf.conf")
        || die "Unable to commit settings: $!\n";
    foreach my $path ( keys( %{ $cfg{services} } ) ) {
        print "Note: Service $path does not exist\n"
            if ( !-e $cfg{services}{$path} );
    }
    print "Enjoy!\n";
    exit;
}

sub load_template {
    my ($template_nb) = @_;
    my %template_cfg;
    my %template_hash = ( 
        1 => 'testmode.conf',
        2 => 'registration.conf',
        3 => 'detection.conf',
        4 => 'reg-detect.conf',
        5 => 'reg-detect-scan.conf',
        6 => 'sessionauth.conf',
        7 => 'reg-detect-vlan.conf',
        8 => 'zen-vlan.conf'
    );
    if ( ! defined($template_hash{$template_nb}) ) {
        croak("Invalid template number $template_nb");
    }
    my $template_filename = "$conf_dir/templates/configurator/"
        . $template_hash{$template_nb};
    die "template $template_filename not found" if ( !-e $template_filename );
    tie %template_cfg, 'Config::IniFiles', ( -file => $template_filename )
        or die "Unable to open $template_filename: $!\n";

    foreach my $section ( tied(%template_cfg)->Sections ) {
        $cfg{$section} = {} if ( !exists( $cfg{$section} ) );
        foreach my $key ( keys( %{ $template_cfg{$section} } ) ) {
            print
                "  Setting option $section.$key to template value $template_cfg{$section}{$key} \n";
            $cfg{$section}{$key} = $template_cfg{$section}{$key};
        }
    }
}

sub config_upgrade {
    my $issues;
    foreach my $section ( tied(%cfg)->Sections ) {
        print
            "  Section $section is now obsolete (you may want to delete it)\n"
            if ( !exists( $default_cfg{$section} )
            && $section !~ /^(passthroughs|proxies|interface)/ );
        foreach my $key ( keys( %{ $cfg{$section} } ) ) {
            if ( !exists( $default_cfg{$section}{$key} ) ) {
                if ( $section !~ /^(passthroughs|proxies|interface)/ ) {
                    print
                        "  Option $section.$key is now obsolete (you may want to delete it)\n";
                    $issues++;
                }
            }
        }
    }
    print "  Looks good!\n" if ( !$issues );
}

sub gatherer {
    my ( $query, $param, @choices ) = @_;
    my $choices;
    my $response;
    my $default;
    $param =~ /^(.+)\.([^\.]+)$/;
    my $section = $1;
    my $element = $2;
    do {
        $default = $default_cfg{$section}{$element}
            if ( defined($section) && defined($element) );
        $default = '<NONE>' if ( !$default );
        my $current = $cfg{$section}{$element}
            if ( defined($section) && defined($element) );
        $current = undef if (defined($current) && ($current eq $default));
        do {
            print "$query (";
            if (defined($current)) {
                print "current: $current, ";
            }
            if ( @choices < 1 ) {
                print "default: $default [?]): ";
            } else {
                print "default: $default) " . "["
                    . join( "|", @choices ) . "|?]: ";
            }
            $response = <STDIN>;
            chop $response;
            if ( $response =~ /^\?$/ ) {
                if ( defined $doc{$param} ) {
                    if (ref($doc{$param}{description}) eq "ARRAY") {
                        print "Detail: "
                           . join( "\n", @{$doc{$param}{description}} );
                    } else {
                        print "Detail: " . $doc{$param}{description};
                    }
                    print "\n";
                } else {
                    print "Sorry no further details, take a guess\n";
                }
            }
            if ( !$response ) {
                if (defined($current)) {
                    $response = $current;
                } else {
                    $response = $default;
                }
            }
        } while ( @choices
            && ( $response && !grep( {/^$response$/} @choices ) )
            || $response =~ /^\?$/ );
    } while ( !confirm($response) );
    $response = "" if ( $response eq "<NONE>" );
    if ( defined($section) && defined($element) ) {
        $cfg{$section} = {} if ( !exists( $cfg{$section} ) );
        $cfg{$section}{$element} = $response;
    }
    return ($response);
}

sub confirm {
    my ($response) = @_;
    my $confirm;
    do {
        print "$response - ok? [y|n] ";
        $confirm = <STDIN>;
    } while ( $confirm !~ /^(y|n)$/i );
    if ( $confirm =~ /^y$/i ) {
        return 1;
    } else {
        return 0;
    }
}

sub questioner {
    my ( $query, $response, @choices ) = @_;
    my $answer;
    my $choices = join( "|", @choices );
    do {
        if (@choices) {
            print "$query [$choices] ";
        } else {
            print "$query: ";
        }
        $answer = <STDIN>;
        $answer =~ s/\s+//g;
    } while ( $answer !~ /^($choices)$/i );
    return $answer if ( !$response );
    if ( $response =~ /^$answer$/i ) {
        return 1;
    } else {
        return 0;
    }
}

sub configuration {
    my ($mode);
    print
        "\n** NOTE: The configuration can be a bit tedious.  If you get bored, you can always just edit $conf_dir/pf.conf directly ** \n\n";
    config_general() if ( !$upgrade );

    if ( !$template ) {
        gatherer(
            "Enable DHCP detector?",
            "network.dhcpdetector",
            ( "enabled", "disabled" )
        );
        gatherer( "Mode (arp|dhcp|vlan)",
            "network.mode", ( "arp", "dhcp", "vlan" ) );
    }

    if ($cfg{network}{mode} eq 'vlan') {
        print "Your isolation mode is " . $cfg{network}{mode}
            . ". If you are interested in SNMP trap statistics"
            . " please create the following crontab entry\n\n"
            . "*/5 * * * * /usr/local/pf/bin/pfcmd traplog update\n";
    }

    config_network( $cfg{network}{mode} );

# ARP
#if (!$template){
#  print "\nARP CONFIGURATION\n";
#  gatherer("What interface should I listen for ARPs on?","arp.listendevice");
#}

    # TRAPPING
    print "\nTRAPPING CONFIGURATION\n";
    gatherer(
        "What range of addresses should be considered trappable (eg. 10.1.1.10-100,10.1.2.0/24)?",
        "trapping.range"
    ) if ( !$template );

    # REGISTRATION
    if ( !$template ) {
        my $registration
            = gatherer( "Do you wish to force registration of systems?",
            "trapping.registration", ( "enabled", "disabled" ) );
        config_registration() if ( $registration =~ /^enabled$/i );
    }

    # DETECTION
    if ( !$template ) {
        gatherer( "Do you wish to enable worm detection?",
            "trapping.detection", ( "enabled", "disabled" ) );
    }
    if ( $cfg{'trapping'}{'detection'} =~ /^enabled$/ ) {
        $cfg{'tmp'}{'monitor'} = "eth1";
        my $int = gatherer( "What is my monitor interface?",
            "tmp.monitor", get_interfaces() );
        delete( $cfg{'tmp'} );

        if ( defined $cfg{"interface $int"}{"type"} ) {
            $cfg{"interface $int"}{"type"} .= ",monitor";
        } else {
            $cfg{"interface $int"}{"type"} = "monitor";
        }

        # debugging issues
        $cfg{"interface $int"}{"ip"} = $cfg{"interface $int"}{"ip"};
    }

    # ALERT
    print "\nALERTING CONFIGURATION\n";
    gatherer(
        "Where would you like notifications of traps, rogue DHCP servers, and other sundry goods sent?",
        "alerting.emailaddr"
    );
    gatherer( "What should I use as my SMTP relay server?",
        "alerting.smtpserver" );

    if ( !$template ) {
        print "\nPORTS CONFIGURATION\n";
        gatherer( "What captive listeners should I enable (imap, pop3)?",
            "ports.listeners" );
        gatherer(
            "Traffic on which ports should be redirected and terminated locally?",
            "ports.redirect"
        );
        gatherer( "What port should the administrative GUI run on?",
            "ports.admin" );
    }

    if ( ( !$upgrade ) && ( $template ne 8 ) ) {
        print "\nDATABASE CONFIGURATION\n";
        gatherer( "Where is my database server?",  "database.host" );
        gatherer( "What port is is listening on?", "database.port" );
        gatherer( "What database should I use?",   "database.db" );
        gatherer( "What account should I use?",    "database.user" );
        gatherer( "What password should I use?",   "database.pass" );
    }
}

sub config_general {

    # GENERAL
    print "GENERAL CONFIGURATION\n";
    $cfg{general}{hostname} = `hostname -s`;
    chop( $cfg{general}{hostname} );
    $cfg{general}{domain} = `hostname -d`;
    chop( $cfg{general}{domain} );
    $cfg{general}{domain} = '<NONE>' if ( $cfg{general}{domain} eq '(none)' );
    $cfg{general}{dnsservers} = "";
    for (`cat /etc/resolv.conf`) {
        $cfg{general}{dnsservers} .= "$1," if (/nameserver (\S+)/);
    }
    chop( $cfg{general}{dnsservers} );
    gatherer( "DNS Domain Name",                     "general.domain" );
    gatherer( "Host Name (without DNS domain name)", "general.hostname" );
    gatherer( "DNS Servers (comma delimited)",       "general.dnsservers" );
    gatherer( "DHCP Servers (comma delimited)",      "general.dhcpservers" );
}

sub config_network {
    my ($mode) = @_;
    my ( @trapping_range, $int, $ip, $mask, $tmp_net );

    # load the defaults
    foreach my $net ( get_networkinfo() ) {
        $int  = $net->{device};
        $ip   = $net->{ip};
        $mask = $net->{mask};
        %{ $cfg{"interface $int"} } = ();
        $cfg{"interface $int"}{'ip'}   = $ip;
        $cfg{"interface $int"}{'mask'} = $mask;
        $cfg{"interface $int"}{'type'} = "internal";
        $tmp_net = new Net::Netmask( $ip, $mask );
        push @trapping_range, $tmp_net->desc;
        $cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);
    }
    $cfg{"trapping"}{"range"} = join( ",", @trapping_range );

    # hack to force default value
    $cfg{'tmp'}{'managed'} = "eth0";
    $int = gatherer( "What is my management interface?",
        "tmp.managed", get_interfaces() );
    delete( $cfg{'tmp'} );

    my $managementIP
        = gatherer( "What is its IP address?", "interface $int.ip" );
    while ( $managementIP eq '' ) {
        print
            "\n** ERROR: management interface IP address can't be empty **\n\n";
        $managementIP
            = gatherer( "What is its IP address?", "interface $int.ip" );
    }
    gatherer( "What is its mask?", "interface $int.mask" );
    $cfg{"interface $int"}{"type"}          = "internal,managed";
    $cfg{"interface $int"}{"authorizedips"} = "";

    $tmp_net = new Net::Netmask( $cfg{"interface $int"}{"ip"},
        $cfg{"interface $int"}{"mask"} );
    $cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);

    #try to determine default gateway
    open( my $proc_fh, '-|', "/sbin/route -n" )
        || die "Can't open /sbin/route $!\n";
    while (<$proc_fh>) {
        if (/^0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)\s+0\.0\.0\.0\s+UG.+$int$/) {
            $cfg{"interface $int"}{"gateway"} = $1;
        }
    }
    close $proc_fh;
    gatherer( "What is my gateway?", "interface $int.gateway" );

    print
        "\n** NOTE: You must manually set testing=disabled in pf.conf to allow PF to send ARPs **\n\n"
        if ( !$template );
}

sub config_registration {
    print
        "\n** NOTE: There are several registration timers/windows to be set in pf.conf - please be sure to review them **\n\n";
    my $auth
        = gatherer(
        "How would you like users to authenticate at registration?",
        "registration.auth", ( "local", "ldap", "radius" ) );

    if ( $cfg{network}{mode} ne 'vlan' ) {
        gatherer(
            "Would you like violation content accessible via iptables passthroughs or apache proxy?",
            "trapping.passthrough",
            ( "iptables", "proxy" )
        );
    } else {
        $cfg{'trapping'}{'passthrough'} = 'proxy';
    }
}

# return an array of hash with network information
#
sub get_networkinfo {
    my $mode = shift @_;
    my @ints;
    open( my $proc_fh, '-|', "/sbin/ifconfig -a" )
        || die "Can't open ifconfig $!\n";
    while (<$proc_fh>) {
        if (/^(\S+)\s+Link/) {
            my $int = $1;
            next if ( $int eq "lo" );
            $_ = <$proc_fh>;
            my %ref;
            if (/inet addr:((?:\d{1,3}\.){3}\d{1,3}).+Mask:((?:\d{1,3}\.){3}\d{1,3})/
                )
            {
                %ref = ( 'device' => $int, 'ip' => $1, 'mask' => $2 );
            }
            push @ints, \%ref if (%ref);
        }
    }
    close $proc_fh;
    return @ints;
}

sub get_interfaces {
    my @ints;
    my @ints2;
    opendir( PROC, "/proc/sys/net/ipv4/conf" )
        || die "Unable to enumerate interfaces: $!";
    @ints = readdir(PROC);
    closedir(PROC);

    foreach my $int (@ints) {
        next
            if ( $int eq "lo"
            || $int eq "all"
            || $int eq "default"
            || $int eq "."
            || $int eq ".." );
        push @ints2, $int;
    }
    return (@ints2);
}

sub installed {
    my ($rpm) = @_;
    return ( !`rpm -q $rpm` !~ /not installed/ );
}

=head1 SEE ALSO

L<installer.pl>

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008-2009 Inverse inc.

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

