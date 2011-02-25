package pf::pfcmd::checkup;

=head1 NAME

pf::pfcmd::checkup - pfcmd's checkup tasks

=head1 DESCRIPTION

This modules holds all the tests performed by 'pfcmd checkup' which is a general configuration sanity test.

=cut

use strict;
use warnings;
use Fcntl ':mode'; # symbolic file permissions
use Readonly;

use pf::config;
use pf::util;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        sanity_check
    );
}

# Error levels
Readonly our $FATAL => "FATAL";
Readonly our $WARN => "WARNING";

# Pieces
Readonly our $SEVERITY => "severity";
Readonly our $MESSAGE => "message";

=head1 SUBROUTINES

=over

=item sanity_check

Returns an array of hashes of the form ( $SEVERITY => ... , $MESSAGE => ... )

=cut
sub sanity_check {
    my (@services) = @_;

    my @problems;
    print "Checking configuration sanity...\n";

    push @problems, service_exists(@services);
    push @problems, interfaces_defined();
    push @problems, interfaces();

    if ( isenabled($Config{'trapping'}{'detection'}) ) {
        push @problems, ids_snort();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'arp' ) {
        push @problems, mode_arp();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'vlan' ) {
        push @problems, mode_vlan();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'dhcp' ) {
        push @problems, mode_dhcp();
    }

    push @problems, database();
    push @problems, web_admin();
    push @problems, registration();
    push @problems, is_config_documented();
    push @problems, extensions();
    push @problems, permissions();

    return @problems;
}

sub service_exists {
    my (@services) = @_;

    my @problems;
    foreach my $service (@services) {
        my $exe = ( $Config{'services'}{$service} || "$install_dir/sbin/$service" );
        if ( !-e $exe ) {
            push @problems, { $SEVERITY => $FATAL, $MESSAGE => "$exe for $service does not exist !"};
        }
    }
    return @problems;
}

=item interfaces_defined

check the config file to make sure interfaces are fully defined

=cut
sub interfaces_defined {

    my @problems;
    foreach my $interface ( tied(%Config)->GroupMembers("interface") ) {
        if ( $Config{$interface}{'type'} !~ /monitor|dhcplistener/ ) {
            if (!defined $Config{$interface}{'ip'}
                || !defined $Config{$interface}{'mask'}
                || !defined $Config{$interface}{'gateway'}
            ) {
                push @problems, { 
                    $SEVERITY => $FATAL, 
                    $MESSAGE => "incomplete network information for $interface"
                };
            }
        }
    }
    return @problems;
}

=item interfaces

check the Netmask objs and make sure a managed and internal interface exist

=cut
sub interfaces {
    my @problems;

    if ( !scalar(@internal_nets) ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "internal network(s) not defined!"
        };
    }
    if ( scalar(@managed_nets) != 1 ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "please define exactly one managed interace"
        };
    }

    my %seen;
    my @tmp_nets;
    push @tmp_nets, @internal_nets;
    push @tmp_nets, @managed_nets;
    foreach my $interface (@tmp_nets) {
        my $device = "interface " . $interface->tag("int");
        if ( !($Config{$device}{'mask'} && $Config{$device}{'ip'}
               && $Config{$device}{'gateway'} && $Config{$device}{'type'})
            && !$seen{$interface}) {
                push @problems, {
                    $SEVERITY => $FATAL,
                    $MESSAGE => "incomplete network information for $device"
                };
        }
        $seen{$interface} = 1;
    }

    return @problems;
}

=item ids_snort

Validation related to the Snort IDS usage 

=cut
sub ids_snort {
    my @problems;

    # make sure a monitor device is present if snort is enabled
    if ( !$monitor_int ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => 
                "monitor interface not defined, please disable trapping.dectection " . 
                "or set an interface type=...,monitor in pf.conf"
        };
    }

    # make sure named pipe 'alert' is present if snort is enabled
    my $snortpipe = "$install_dir/var/alert";
    if ( !-p $snortpipe ) {
        if ( !POSIX::mkfifo( $snortpipe, oct(666) ) ) {
            push @problems, {
                $SEVERITY => $FATAL,
                $MESSAGE => "snort alert pipe ($snortpipe) does not exist and unable to create it"
            };
        }
    }

    if ( !-x $Config{'services'}{'snort'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "snort binary is not executable / does not exist!"
        };
    }

    return @problems;
}

=item mode_arp

Configuration validation for ARP mode

=cut
sub mode_arp {
    my @problems;

    # stuffing warning
    if ( isenabled( $Config{'arp'}{'stuffing'} ) ) {
        push @problems, {
            $SEVERITY => $WARN,
            $MESSAGE => "ARP stuffing is enabled...this is dangerous!"
        };
    }

    # network size warning
    my $internal_total;
    foreach my $internal_net (@internal_nets) {
        if ( $internal_net->bits() < 16 && isenabled( $Config{'general'}{'caching'} ) ) {
            push @problems, {
                $SEVERITY => $WARN,
                $MESSAGE => "network $internal_net is larger than a /16 - you must disable general.caching!"
            };
        }
        $internal_total += $internal_net->size();
    }

    # test to do in ARP mode
    push @problems, nameservers();

    return @problems;
}

=item mode_vlan

Configuration validation for VLAN Isolation mode

=cut
sub mode_vlan {
    my @problems;

    # make sure trapping.passthrough=proxy if network.mode is set to vlan
    if ( $Config{'trapping'}{'passthrough'} eq 'iptables' ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "Please set trapping.passthrough to proxy while using VLAN isolation mode"
        };
    }

    # make sure that skip_mode is disabled in VLAN isolation
    if ( !isdisabled($Config{'registration'}{'skip_mode'}) ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "registration skip_mode is currently incompatible with VLAN isolation"
        };
    }

    # make sure that expire_mode session is disabled in VLAN isolation
    if (lc($Config{'registration'}{'expire_mode'}) eq 'session') {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => 
                "automatic node expiration mode ".$Config{'registration'}{'expire_mode'}
                . " is currently incompatible with VLAN isolation"
        };
    }

    # make sure that networks.conf is not empty when vlan.dhcpd
    # is enabled
    if ((isenabled($Config{'vlan'}{'dhcpd'})) && ((!-e "$conf_dir/networks.conf") || (-z "$conf_dir/networks.conf"))) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "networks.conf cannot be empty when vlan.dhcpd is enabled"
        };
    }

    # make sure that networks.conf is not empty when vlan.named
    # is enabled
    if ((isenabled($Config{'vlan'}{'named'})) && ((!-e "$conf_dir/networks.conf") || (-z "$conf_dir/networks.conf"))) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "networks.conf cannot be empty when vlan.named is enabled"
        };
    }

    return @problems;
}

=item mode_dhcp

Validation for the DHCP mode

=cut
sub mode_dhcp {
    my @problems;

    # make sure dhcp information is complete and valid
    my @dhcp_scopes;
    foreach my $dhcp ( tied(%Config)->GroupMembers("dhcp") ) {
        if ( defined( $Config{$dhcp}{'registered_scopes'} ) ) {
            @dhcp_scopes = split( /\s*,\s*/, $Config{$dhcp}{'registered_scopes'} );
        }
        if ( defined( $Config{$dhcp}{'unregistered_scopes'} ) ) {
            push @dhcp_scopes, split( /\s+/, $Config{$dhcp}{'unregistered_scopes'} );
        }
        if ( defined( $Config{$dhcp}{'isolation_scopes'} ) ) {
            push @dhcp_scopes, split( /\s+/, $Config{$dhcp}{'isolation_scopes'} );
        }
    }

    if ( scalar(@dhcp_scopes) == 0 ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "missing dhcp scope information"
        };
    }

    foreach my $scope (@dhcp_scopes) {
        if (!defined $Config{ 'scope ' . $scope }{'network'}
            || !defined $Config{ 'scope ' . $scope }{'gateway'}
            || !defined $Config{ 'scope ' . $scope }{'range'} ) {
                push @problems, {
                    $SEVERITY => $FATAL,
                    $MESSAGE => "incomplete dhcp scope information for $scope"
                };
        }

        my $found = 0;
        foreach my $int (@internal_nets) {
            if ( $Config{ 'interface ' . $int->tag('int') }{'ip'} eq $Config{ 'scope ' . $scope }{'gateway'} ) {
                $found = 1;
                next;
            }
        }
        if ( !$found ) {
            push @problems, {
                $SEVERITY => $WARN,
                $MESSAGE => 
                    "dhcp scope $scope gateway ($Config{'scope '.$scope}{'gateway'}) is not bound to internal interface"
            };
        }
    }

    # FIXME this probably needs to be done on dhcp mode startup and not in checkup phase
    if ( !-e "$conf_dir/registered.mac" ) {
        my $file_fh;
        open $file_fh, '>>', "$conf_dir/registered.mac";
        print {$file_fh} "#autogenerated";
        close $file_fh;
    }

    if ( !-e "$conf_dir/isolated.mac" ) {
        my $file_fh;
        open $file_fh, '>>', "$conf_dir/isolated.mac";
        print {$file_fh} "#autogenerated";
        close $file_fh;
    }

    # test to do in ARP mode
    push @problems, nameservers();

    return @problems;
}

=item database

database check

=cut
sub database {
    my @problems;

    # make sure pid 1 exists
    require pf::person;
    if ( !pf::person::person_exist(1) ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "person user id 1 must exist - please reinitialize your database"
        };
    }

    return @problems;
}

=item web_admin

Web Administration interface checks

=cut
sub web_admin {
    my @problems;

    # make sure admin port exists
    if ( !$Config{'ports'}{'admin'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "please set the web admin port in pf.conf (ports.admin)"
        };
    }

    return @problems;
}

=item nameservers

We need DNS Servers defined.
Applies only to arp and dhcp mode.

=cut
sub nameservers {
    my @problems;

    # make sure dns servers exist
    if ( !$Config{'general'}{'dnsservers'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE =>
                "please set the dns servers list in pf.conf (general.dnsservers). " . 
                "If this is not set users in isolation will not be able to resolve hostnames, " . 
                "and will not able to reach PacketFence!"
        };
    }

    return @problems;
}

=item registration

Registration configuration sanity

=cut
sub registration {
    my @problems;

    # warn when scan.registration=enabled and trapping.registration=disabled
    if ( isenabled( $Config{'scan'}{'registration'} ) && isdisabled( $Config{'trapping'}{'registration'} ) ) {
        push @problems, {
            $SEVERITY => $WARN,
            $MESSAGE => "scan.registration is enabled but trapping.registration is not ... this is strange!"
        };
    }

    # registration.skip_mode validation
    if ( $Config{'registration'}{'skip_mode'} eq "deadline" && !$Config{'registration'}{'skip_deadline'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE =>
                "pf.conf value registration.skip_deadline is mal-formed or null! " . 
                "(format should be that of the 'date' command)"
        };
    } elsif ( $Config{'registration'}{'skip_mode'} eq "windows" && !$Config{'registration'}{'skip_window'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "pf.conf value registration.skip_window is not defined!"
        };
    }

    # registration.expire_mode validation
    if ( $Config{'registration'}{'expire_mode'} eq "deadline" && !$Config{'registration'}{'expire_deadline'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => 
                "pf.conf value registration.expire_deadline is mal-formed or null! " . 
                "(format should be that of the 'date' command)"
        };
    } elsif ( $Config{'registration'}{'expire_mode'} eq "window" && !$Config{'registration'}{'expire_window'} ) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "pf.conf value registration.expire_window is not defined!"
        };
    }

    return @problems;
}

sub is_config_documented {
    my @problems;

    #compare configuration with documentation
    tie my %myconfig, 'Config::IniFiles', (
        -file   => $config_file,
        -import => Config::IniFiles->new( -file => $default_config_file )
    );
    tie my %documentation, 'Config::IniFiles', ( -file => $conf_dir . "/documentation.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        my $message = join( "\n", @errors ) . "\n";
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE => "problem reading documentation.conf. Error: $message"
        };
        return @problems;
    }

    #starting with documentation vs configuration
    #i.e. make sure that pf.conf contains everything defined in
    #documentation.conf
    foreach my $section ( sort tied(%documentation)->Sections ) {
        my ( $group, $item ) = split( /\./, $section );
        my $type = $documentation{$section}{'type'};

        next if ( $section =~ /^(proxies|passthroughs)$/ || $group =~ /^(dhcp|scope|interface|services)$/ );
        next if ( ( $group eq 'alerting' ) && ( $item eq 'fromaddr' ) );
        next if ( ( $group eq 'arp' )      && ( $item eq 'listendevice' ) );

        if ( defined( $Config{$group}{$item} ) ) {
            if ( $type eq "toggle" ) {
                if ( $Config{$group}{$item} !~ /^$documentation{$section}{'options'}$/ ) {
                    push @problems, {
                        $SEVERITY => $FATAL,
                        $MESSAGE => 
                            "pf.conf value $group\.$item must be one of the following: "
                            . $documentation{$section}{'options'}
                    };
                }
            } elsif ( $type eq "time" ) {
                if ( $myconfig{$group}{$item} !~ /\d+[smhdw]$/ ) {
                    push @problems, {
                        $SEVERITY => $FATAL,
                        $MESSAGE =>
                            "pf.conf value $group\.$item does not explicity define interval (eg. 7200s, 120m, 2h) " .
                            "- please define it before running packetfence"
                    };
                }
            } elsif ( $type eq "multi" ) {
                my @selectedOptions = split( /\s*,\s*/, $myconfig{$group}{$item} );
                my @availableOptions = split( /\s*[;\|]\s*/, $documentation{$section}{'options'} );
                foreach my $currentSelectedOption (@selectedOptions) {
                    if ( grep(/^$currentSelectedOption$/, @availableOptions) == 0 ) {
                        push @problems, {
                            $SEVERITY => $FATAL,
                            $MESSAGE =>
                                "pf.conf values for $group\.$item must be among the following: " .
                                $documentation{$section}{'options'}
                                . " but you used $currentSelectedOption"
                                . ". If you are sure of this choice, please "
                                . " update conf/documentation.conf"
                        };
                    }
                }
            }
        } elsif ( $Config{$group}{$item} ne "0" ) {
            push @problems, {
                $SEVERITY => $FATAL,
                $MESSAGE => "pf.conf value $group\.$item is not defined!"
            };
        }
    }

    #and now the opposite way around
    #i.e. make sure that pf.conf does not contain more
    #than what is documented in documentation.conf
    foreach my $section (keys %Config) {
        next if ( ($section eq "proxies") || ($section eq "passthroughs") || ($section eq "")
                  || ($section =~ /^(services|interface|dhcp|scope)/));

        foreach my $item  (keys %{$Config{$section}}) {
            if ( !defined( $documentation{"$section.$item"} ) ) {
                push @problems, {
                    $SEVERITY => $FATAL,
                    $MESSAGE => "unknown configuration parameter $section.$item ".
                    "if you added the parameter yourself make sure it is present in conf/documentation.conf"
                };
            }
        }
    }

    return @problems;
}

=item extensions

Performs version checking of the extension points.

=cut
sub extensions {
    my @problems;

    require pf::radius::custom;
    if ($RADIUS_API_LEVEL > pf::radius::custom->VERSION()) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE =>
                "RADIUS Extension point (pf::radius::custom) is not at the correct API level. " .
                "Did you read the UPGRADE document?"
        };
    }

    require pf::vlan::custom;
    if ($VLAN_API_LEVEL > pf::vlan::custom->VERSION()) {
        push @problems, {
            $SEVERITY => $FATAL,
            $MESSAGE =>
                "VLAN Extension point (pf::vlan::custom) is not at the correct API level. " .
                "Did you read the UPGRADE document?"
        };
    }

    return @problems;
}

=item permissions

Checking some important permissions

=cut
sub permissions {
    my @problems;

    # pfcmd needs to be setuid / setgid and 
    # TODO once #1087 is fixed, promote to fatal or remove need for setuid/setgid
    my (undef, undef, $pfcmd_mode, undef, $pfcmd_owner, $pfcmd_group) = stat($bin_dir . "/pfcmd");
    if (!($pfcmd_mode & S_ISUID && $pfcmd_mode & S_ISGID)) {
        push @problems, {
            $SEVERITY => $WARN,
            $MESSAGE => "pfcmd needs setuid and setgid bit set to run properly. Fix with chmod ug+s pfcmd"
        };
    }
    # pfcmd needs to be owned by root (owner id 0 / group id 0) 
    # TODO once #1087 is fixed, promote to fatal or remove need for setuid/setgid
    if ($pfcmd_owner || $pfcmd_group) {
        push @problems, {
            $SEVERITY => $WARN,
            $MESSAGE => "pfcmd needs to be owned by root. Fix with chown root:root pfcmd"
        };
    }

    # TODO verify log files ownership (issue #1191)

    return @problems;
}

=back

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

1;

# vim: set shiftwidth=4:
# vim: set tabstop=4:
# vim: set autoindent:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
