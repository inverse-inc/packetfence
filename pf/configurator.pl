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

=item * choice between different PacketFence working mode

=item * choice of enforcement methods (VLANs, Inline, Both)

=item * general PacketFence configurations

=item * database configuration

=item * detection (IDS) configuration

=item * interfaces configuration

=item * networks configuration

=back

=head1 DEPENDENCIES

=over

=item * Carp

=item * Config::IniFiles

=item * FindBin

=item * Net::Netmask

=item * Term::ReadKey

=cut

use strict;
use warnings;

use Carp;
use Config::IniFiles;
use FindBin;
use Net::Interface;
use Net::Netmask;
use Term::ReadKey;

my $install_dir = $FindBin::Bin;
my $conf_dir    = "$install_dir/conf";

# Check if user is root
die( "Aie! You must be root!\n" ) if ( $< != 0 );


my ( %default_pf_cfg, %current_pf_cfg, %pf_cfg, %current_networks_cfg, %networks_cfg, %doc, %violations );
my ( $enforcement, @network_types, @trapping_range, $upgrade );


# Creating defaults tied hashes
tie (%default_pf_cfg, 'Config::IniFiles', (-file => "$conf_dir/pf.conf.defaults"))
        or die "Invalid configuration template: $!\n";
tie (%violations, 'Config::IniFiles', (-file => "$conf_dir/violations.conf"))
        or die "Invalid violation file: $!\n";
tie (%doc, 'Config::IniFiles', (-file => "$conf_dir/documentation.conf"))
        or die "Invalid documentation file: $!\n";


# Check if any PacketFence configurations files exists (upgrade or new install)
if ( $upgrade = check_for_upgrade() ) {
    # Open current config files
    tie (%current_pf_cfg, 'Config::IniFiles', (-file => "$conf_dir/pf.conf"))
        or die "Invalid existing PacketFence configuration file: $!\n";
    tie (%current_networks_cfg, 'Config::IniFiles', (-file => "$conf_dir/networks.conf"))
        or die "Invalid existing networks configuration file: $!\n";

    # Create new config files from old ones
    tie (%pf_cfg, 'Config::IniFiles', (-import => tied(%current_pf_cfg)));
    tie (%networks_cfg, 'Config::IniFiles');

    # Deleting interfaces sections from pf.conf to make all interfaces availables
    foreach my $section ( tied(%pf_cfg)->Sections ) {
        next if ( $section !~ /^interface (.+)/i );
        delete $pf_cfg{$section};
    }
} else {
    # Create new config files from template
    tie (%pf_cfg, 'Config::IniFiles', (-import => tied(%default_pf_cfg)));
    tie (%networks_cfg, 'Config::IniFiles');
}


print "\nEntering PacketFence configuration mode... Be prepared...\n";

print "\nThe following configuration script will help you configure PacketFence using some basic predefined templates. 
Once done, your PacketFence installation will be fully functionnal (if everything's go as expected) and will be 
ready to use. For more advanced configurations, don't be shy to take a look at the main configuration file 
($conf_dir/pf.conf) and it's documentation file $conf_dir/documentation.conf\n";

print "\nHere are the steps that will be performed:
    - Choice of configuration template and enforcement method
    - General configuration of the PacketFence server
    - Configuration of enforcement networks\n";

print "\n*** Please note that the following configuration script can be a bit tedious. If you get bored, just leave and 
edit $conf_dir/pf.conf directly. ***\n\n";

my $template_list = << "END_TEMPLATE_LIST";
What kind of configuration would you like to put in place?
        1) PacketFence standalone (Basic configuration)
        2) PacketFence with detection (SNORT)
Configuration choice: 
END_TEMPLATE_LIST

my $template = questioner ( $template_list, '', (1 .. 2) );

print "\n*** The following configuration script won't configure a remote SNORT probe only a local one. ***\n";

my $enforcement_list = << "END_ENFORCEMENT_LIST";
What kind of enforcement would you like to use for isolation?
        1) VLANs
        2) Inline
        3) VLANs and Inline
Enforcement choice:
END_ENFORCEMENT_LIST

$enforcement = questioner ( $enforcement_list, '', (1 .. 3) );
push @network_types, "isolation";

# General configuration
config_pf_general();

# Detection configuration
if ( $template eq 2 ) {
    config_pf_detection();
}

# Database configuration
config_pf_database();

# Interfaces configuration
config_pf_interfaces();

# Networks configuration
config_pf_networks();

write_configs();

exit;


=item * config_pf_general

=cut
sub config_pf_general {
    print "\nPACKETFENCE GENERAL CONFIGURATION\n";

    $pf_cfg{general}{hostname} = `hostname -s`;
    chop ( $pf_cfg{general}{hostname} );
    $pf_cfg{general}{domain} = `hostname -d`;
    chop ( $pf_cfg{general}{domain} );
    $pf_cfg{general}{domain} = '<NONE>' if ( $pf_cfg{general}{domain} eq '(none)' );    

    # General configs
    gatherer ( "What's my host name (without the domain name)? ", \%pf_cfg, 'general.hostname' );
    gatherer ( "What's my domain name? ", \%pf_cfg, 'general.domain' );
    gatherer ( "DHCP servers, including me (comma delimited): ", \%pf_cfg, 'general.dhcpservers' );

    # Administration port
    gatherer ( "What will be my webGUI admin port?", \%pf_cfg, 'ports.admin' );

    # Alerting
    gatherer ( "Which email address should receive my notifications and other sundry goods sent?", \%pf_cfg,
            'alerting.emailaddr' );
    gatherer ( "Should I send notification emails when services managed by PacketFence are not running?", \%pf_cfg,
            'servicewatch.email', ("enabled", "disabled") );
    gatherer ( "Should I restart services I manage and that seems halted? (Remember that you'll need to install a cron entry. See conf/pf.conf.defaults)", \%pf_cfg, 'servicewatch.restart',
            ("enabled", "disabled") );

    # Registration
    gatherer ( "Do you want to force registration of devices? ", \%pf_cfg, 'trapping.registration', 
            ("enabled", "disabled") );
    if ( $pf_cfg{trapping}{registration} eq "enabled" ) {
        gatherer ( "How would you like users to authenticate at registration?", \%pf_cfg, 'registration.auth', 
                ("local", "ldap", "radius") );
        push @network_types, "registration";
    }

    # High-availability
    my $ha = gatherer ( "Do you want to use a high-availability setup?", \%pf_cfg, '', ("enabled", "disabled") );
    if ( $ha eq "enabled" ) {
        my $ha_int = gatherer ( "What is my high-availability interface?", \%pf_cfg, '', get_interfaces() );
        %{ $pf_cfg{"interface $ha_int"} } = ();
        $pf_cfg{"interface $ha_int"}{'type'}   = "high-availability";
    }
}


=item * config_pf_detection

=cut
sub config_pf_detection {
    print "\nPACKETFENCE DETECTION (SNORT) CONFIGURATION\n";

    $pf_cfg{"trapping"}{"detection"} = "enabled";

    my $mon_int = gatherer ( "What is my monitor interface?", \%pf_cfg, '', get_interfaces() );
    %{ $pf_cfg{"interface $mon_int"} } = ();
    $pf_cfg{"interface $mon_int"}{"type"}   = "monitor";
}


=item * config_pf_database

=cut
sub config_pf_database {
    print "\nPACKETFENCE DATABASE CONFIGURATION\n";
    gatherer ( "Where is my database server?", \%pf_cfg, "database.host" );
    gatherer ( "Which port is it listening on?", \%pf_cfg, "database.port" );
    gatherer ( "Which database should I use?", \%pf_cfg, "database.db" );
    gatherer ( "Which account should I use?", \%pf_cfg, "database.user" );
    password_gatherer ( "What is the password associated with this account?", "database.pass" );
}


=item * config_pf_interfaces

=cut
sub config_pf_interfaces {
    my ( $int, $tmp_net, $type, $management );
 
    print "\nPACKETFENCE INTERFACES CONFIGURATION\n";
    print "\n*** PacketFence configuration rely on your network interfaces attributes. Prior to continue, make 
sure that those are correctly configured using ifconfig (You should open a new term window to avoid closing this 
configuration process) ***\n";

    foreach my $net ( get_networkinfos() ) {
        next if ( defined $pf_cfg{"interface $net->{device}"} );
        if ( questioner ( "\nIs $net->{device} ( $net->{ip} ) to be used by PacketFence?", 'y', ( 'y', 'n' ) ) ) {
            
            $int = $net->{device};

            $tmp_net = new Net::Netmask( $net->{ip}, $net->{mask} );

            %{ $pf_cfg{"interface $int"} } = ();
            $pf_cfg{"interface $int"}{'ip'}   = $net->{ip};
            $pf_cfg{"interface $int"}{'mask'} = $net->{mask};
            $pf_cfg{"interface $int"}{"gateway"} = $tmp_net->nth(1);

            if ( !$management ) {
                $type = gatherer ( "What kind of interface is it?", \%pf_cfg, "interface $int.type", 
                        ("internal", "management") );
                $management = 1 if ( $type eq 'management' );
            } else {
                $type = "internal";
                $pf_cfg{"interface $int"}{'type'} = $type;
            }

            if ($type ne "management") {
                if ( $enforcement eq 1 ) {
                    $pf_cfg{"interface $int"}{'enforcement'} = "vlan";
                } elsif ( $enforcement eq 2 ) {
                    $pf_cfg{"interface $int"}{'enforcement'} = "inline";
                } else {
                    gatherer ( "How does network access will be enforced using this interface?", \%pf_cfg, 
                            "interface $int.enforcement", ("vlan", "inline") );
                }
            }

            push @trapping_range, $tmp_net->desc if ( $type ne "management" );
        }
    }

    $pf_cfg{"trapping"}{"range"} = join( ",", @trapping_range );
}


=item * config_pf_networks

=cut
sub config_pf_networks {
    print "\nPACKETFENCE NETWORKS CONFIGURATION\n";
    print "\n*** PacketFence will now be configured to act as a DHCP / DNS server on the enforcement enabled " . 
            "interfaces ***\n";

    push @network_types, "other";

    foreach my $net ( get_networkinfos() ) {
        my ( $type, $type_formatted );

        next if ( !$pf_cfg{"interface $net->{device}"}{"enforcement"} );

        my $int = $net->{"device"};

        print "\nInterface $int ($net->{ip} mask $net->{mask})\n";
        my $prefix = gatherer ( "What's the network prefix? (ex: 192.168.1.0)" );
        
        $type = "inline" if ( $pf_cfg{"interface $int"}{"enforcement"} eq "inline" );
        $type = gatherer ( "Which type of network is it?", '', '', @network_types ) if ( !defined $type );
        $type_formatted = $type;
        $type_formatted = "vlan-" . $type if ( $type eq "isolation" || $type eq "registration" );

        %{ $networks_cfg{$prefix} } = ();
        $networks_cfg{$prefix}{"type"} = $type_formatted if ( $type ne "other" );
        $networks_cfg{$prefix}{"netmask"} = $net->{"mask"};
        $networks_cfg{$prefix}{"gateway"} = $net->{"ip"};
        $networks_cfg{$prefix}{"next_hop"} = "";
        if ( $type eq "inline" ) {
            $networks_cfg{$prefix}{"named"} = "disabled";
            for (`cat /etc/resolv.conf`) {
                $networks_cfg{$prefix}{"dns"} .= "$1," if (/nameserver (\S+)/);
            }
            chop( $networks_cfg{$prefix}{"dns"} );
        } else {
            $networks_cfg{$prefix}{"named"} = "enabled";
            $networks_cfg{$prefix}{"dns"} = $net->{"ip"};
        }
        $networks_cfg{$prefix}{"domain-name"} = $type . "." . $pf_cfg{"general"}{"domain"};
        $networks_cfg{$prefix}{"dhcpd"} = "enabled";
        gatherer ( "What is the DHCP scope first address?", \%networks_cfg, "$prefix.dhcp_start" );
        gatherer ( "What is the DHCP scope last address?", \%networks_cfg, "$prefix.dhcp_end" );
        $networks_cfg{$prefix}{"dhcp_default_lease_time"} = "20";
        $networks_cfg{$prefix}{"dhcp_max_lease_time"} = "20";
    }
}


=item * write_configs

=cut
sub write_configs {

    print "Writing PacketFence and networks configurations\n";

    # Delete keys equals to their defaults
    foreach my $section ( tied(%pf_cfg)->Sections ) {
        next if ( !exists($default_pf_cfg{$section}) );
        foreach my $key ( keys(%{$pf_cfg{$section}}) ) {
            next if ( !exists($default_pf_cfg{$section}{$key}) );
            if ( $pf_cfg{$section}{$key} =~ /$default_pf_cfg{$section}{$key}/i ) {
                delete $pf_cfg{$section}{$key};
                tied(%pf_cfg)->DeleteParameterComment($section, $key);
            }
        }
    }

    # Delete empty sections from pf_cfg
    foreach my $section ( tied(%pf_cfg)->Sections ) {
        delete $pf_cfg{$section} if ( scalar(keys(%{$pf_cfg{$section}})) == 0 );
    }

    # Writing PacketFence configuration in pf.conf
    tied(%pf_cfg)->WriteConfig("$conf_dir/pf.conf")
            or die "Error writing PacketFence configuration in pf.conf: $!\n";

    # Delete empty sections from networks_cfg
    foreach my $section ( tied(%networks_cfg)->Sections ) {
        delete $networks_cfg{$section} if ( scalar(keys(%{$networks_cfg{$section}})) == 0 );
    }

    # Writing networks configuration in networks.conf
    tied(%networks_cfg)->WriteConfig("$conf_dir/networks.conf")
            or die "Error writing networks configuration in networks.conf: $!\n";

    # Writing old configs files
    if ( $upgrade ) {
        tied(%current_pf_cfg)->WriteConfig("$conf_dir/pf.conf.old")
            or die "Error writing current PacketFence configuration in pf.conf.old: $!\n";
        tied(%current_networks_cfg)->WriteConfig("$conf_dir/networks.conf.old")
            or die "Error writing current networks configuration in networks.conf.old: $!\n";
    }
}


=item * check_for_upgrade

=cut
sub check_for_upgrade {
    my $upgrade = 0;

    print "Checking for existing PacketFence configuration file...\n";

    if ( (-e "$conf_dir/pf.conf") && (-e "$conf_dir/networks.conf") ) {
        print "Existing PacketFence configuration files found; upgrading...\n";
        $upgrade = 1;

        exit if ( questioner( "Would you like to modify the existing configuration?", 'n', ( 'y', 'n' ) ) );

    } else {
        print "No existing PacketFence configuration files found; configuring...\n";
    }

    return $upgrade;
}


=item * get_interfaces

=cut
sub get_interfaces {
    my @ints;

    foreach my $int (Net::Interface->interfaces()) {
        next if ( "$int" eq "lo" );
        push @ints, "$int"; # quotes required because of Net::Interface's overloaded operators
    }

    return (@ints);
}


=item * get_networkinfos

=cut
sub get_networkinfos {
    my @ints;

    open ( my $proc_fh, '-|', "/sbin/ifconfig -a" ) || die "Can't open ifconfig $!\n";

    while ( <$proc_fh> ) {
        if ( /^(\S+)\s+Link/ ) {
            my $int = $1;
            next if ( $int eq "lo" );
            $_ = <$proc_fh>;

            my %ref;
            if ( /inet addr:((?:\d{1,3}\.){3}\d{1,3}).+Mask:((?:\d{1,3}\.){3}\d{1,3})/ ) {
                %ref = ( 'device' => $int, 'ip' => $1, 'mask' => $2 );
            }

            push @ints, \%ref if (%ref);
        }
    }

    close $proc_fh;
    return @ints;
}


=item * get_enforcement_enabled_interfaces

=cut
sub get_enforcement_enabled_interfaces {
    my @ints;

    foreach my $net ( get_networkinfos() ) {
        my $int = $net->{device};
        if ( $pf_cfg{"interface $int"}{'enforcement'} ) {
            push @ints, $int;
        }
    }

    return @ints;
}


=item * questioner

=cut
sub questioner {
    my ( $query, $response, @choices ) = @_;

    my $answer;
    my $choices = join("|", @choices);

    do {
        if ( @choices ) {
            print "$query [$choices] ";
        } else {
            print "$query: ";
        }
        $answer = <STDIN>;
        $answer =~ s/\s+//g;
    } 
    while ( $answer !~ /^($choices)$/i );

    return $answer if ( !$response );

    if ( $response =~ /^$answer$/i ) {
        return 1;
    } else {
        return 0;
    }
}


=item * gatherer

=cut
sub gatherer {
    my ( $query, $tied_hash_ref, $params, @choices ) = @_;

    my $default;
    my $current;
    my $response;

    $params =~ /^(.+)\.([^\.]+)$/ if ( defined($params) );
    my $section = $1;
    my $element = $2;
    my %tied_hash = %$tied_hash_ref if ( $tied_hash_ref );

    do {
        $default = $default_pf_cfg{$section}{$element} if ( defined($section) && defined($element) );
        $default = '<NONE>' if ( !$default );
        $current = $tied_hash{$section}{$element} if ( defined($section) && defined($element) );

        do {
            print "$query (";
            print "default: $default | " if ( defined($default) );
            print "current: $current | " if ( defined($current) );
            print "[ " . join("|", @choices) . " ] | " if ( @choices );
            print "?) ";
            chomp($response = <STDIN>);

            if ( $response =~ /^\?$/ ) {
                if ( defined($doc{$params}) ) {
                    if ( ref($doc{$params}{description}) eq "ARRAY" ) {
                        print "Detail:\n" . join( "\n", @{$doc{$params}{description}} );
                    } else {
                        print "Detail:\n" . $doc{$params}{description};
                    }
                    print "\n";
                } else {
                    print "Sorry no further details, take a guess\n";
                }
            }

            if ( !$response ) {
                if ( defined($current) ) {
                    $response = $current;
                } else {
                    $response = $default;
                }
            }

        } while ( @choices && ( $response && !grep( {/^$response$/} @choices ) ) || $response =~ /^\?$/ );
    } while ( !confirm($response) );

    $response = "" if ( $response eq "<NONE>" );
    if ( defined($section) && defined($element) ) {
        $tied_hash{$section} = {} if ( !exists( $tied_hash{$section} ) );
        $tied_hash{$section}{$element} = $response;
    }

    return ($response);
}


=item * confirm

=cut
sub confirm {
    my ( $response ) = @_;

    my $confirm;

    do {
        print "$response - ok? [y|n] ";
        $confirm = <STDIN>;
    } 
    while ( $confirm !~ /^(y|n)$/i );
    
    if ( $confirm =~ /^y$/i ) {
        return 1;
    } else {
        return 0;
    }
}


=item * password_gatherer

=cut
sub password_gatherer {
    my ( $query, $param ) = @_;
    my $response;
    $param =~ /^(.+)\.([^\.]+)$/;
    my $section = $1;
    my $element = $2;
    my $confirm;

    do {
        ReadMode('noecho');
        print "$query: ";
        chomp($response = ReadLine(0));
        print "\n";
        print "Confirm: ";
        chomp($confirm = ReadLine(0));
        print "\n";
        ReadMode('restore');
    } while ( !password_confirm($response, $confirm) );

    if ( defined($section) && defined($element) ) {
        $pf_cfg{$section} = {} if ( !exists( $pf_cfg{$section} ) );
        $pf_cfg{$section}{$element} = $response;
    }

    return ($response);
}


=item * password_confirm

=cut
sub password_confirm {
    my ($response, $confirm) = @_;
    if ( $response eq $confirm ) {
        return 1;
    } else {
        print "Passwords don't match! Try again.\n";
        return 0;
    }
}


=back

=head1 SEE ALSO

L<installer.pl>

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008-2012 Inverse inc.

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
