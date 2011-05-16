package pf::pfcmd::checkup;

=head1 NAME

pf::pfcmd::checkup - pfcmd's checkup tasks

=head1 DESCRIPTION

This modules holds all the tests performed by 'pfcmd checkup' which is a general configuration sanity test.

=cut

use strict;
use warnings;
use Fcntl ':mode'; # symbolic file permissions
use Try::Tiny;
use Readonly;

use pf::config;
use pf::util;
use pf::services;
use pf::trigger;

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

our @problems;

=head1 SUBROUTINES

=over

=item add_problem

Add a problem to the problem list.

add_problem( severity, message );

=cut
sub add_problem {
    my ($severity, $message) = @_;

    push @problems, {
        $SEVERITY => $severity,
        $MESSAGE => $message
    };
}

=item sanity_check

Returns an array of hashes of the form ( $SEVERITY => ... , $MESSAGE => ... )

=cut
sub sanity_check {
    my (@services) = @_;

    # emptying problem list
    @problems = ();
    print "Checking configuration sanity...\n";

    service_exists(@services);
    interfaces_defined();
    interfaces();

    if ( isenabled($Config{'vlan'}{'radius'} ) ) {
        freeradius();
    }

    if ( isenabled($Config{'trapping'}{'detection'}) ) {
        ids_snort();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'arp' ) {
        mode_arp();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'vlan' ) {
        mode_vlan();
    }

    if ( lc($Config{'network'}{'mode'}) eq 'dhcp' ) {
        mode_dhcp();
    }

    database();
    apache();
    web_admin();
    registration();
    is_config_documented();
    extensions();
    permissions();
    violations();

    return @problems;
}

sub service_exists {
    my (@services) = @_;

    foreach my $service (@services) {
        my $exe = ( $Config{'services'}{$service} || "$install_dir/sbin/$service" );
        if ( !-e $exe ) {
            add_problem( $FATAL, "$exe for $service does not exist !" );
        }
    }
}

=item interfaces_defined

check the config file to make sure interfaces are fully defined

=cut
sub interfaces_defined {

    foreach my $interface ( tied(%Config)->GroupMembers("interface") ) {
        if ( $Config{$interface}{'type'} !~ /monitor|dhcplistener/ ) {
            if (!defined $Config{$interface}{'ip'}
                || !defined $Config{$interface}{'mask'}
                || !defined $Config{$interface}{'gateway'}
            ) {
                add_problem( $FATAL, "incomplete network information for $interface" );
            }
        }
    }
}

=item interfaces

check the Netmask objs and make sure a managed and internal interface exist

=cut
sub interfaces {

    if ( !scalar(@internal_nets) ) {
        add_problem( $FATAL, "internal network(s) not defined!" );
    }
    if ( scalar(@managed_nets) != 1 ) {
        add_problem( $FATAL, "please define exactly one managed interace" );
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
                add_problem( $FATAL, "incomplete network information for $device" );
        }
        $seen{$interface} = 1;
    }

}

=item freeradius

Validation related to the FreeRADIUS daemon

=cut
sub freeradius {

    if ( !-x $Config{'services'}{'radiusd'} ) {
        add_problem( $FATAL, "radiusd binary is not executable / does not exist!" );
    }

}

=item ids_snort

Validation related to the Snort IDS usage 

=cut
sub ids_snort {

    # make sure a monitor device is present if snort is enabled
    if ( !$monitor_int ) {
        add_problem( $FATAL, 
            "monitor interface not defined, please disable trapping.dectection " . 
            "or set an interface type=...,monitor in pf.conf"
        );
    }

    # make sure named pipe 'alert' is present if snort is enabled
    my $snortpipe = "$install_dir/var/alert";
    if ( !-p $snortpipe ) {
        if ( !POSIX::mkfifo( $snortpipe, oct(666) ) ) {
            add_problem( $FATAL, "snort alert pipe ($snortpipe) does not exist and unable to create it" );
        }
    }

    if ( !-x $Config{'services'}{'snort'} ) {
        add_problem( $FATAL, "snort binary is not executable / does not exist!" );
    }

}

=item mode_arp

Configuration validation for ARP mode

=cut
sub mode_arp {

    # stuffing warning
    if ( isenabled( $Config{'arp'}{'stuffing'} ) ) {
        add_problem( $WARN, "ARP stuffing is enabled...this is dangerous!" );
    }

    # network size warning
    my $internal_total;
    foreach my $internal_net (@internal_nets) {
        if ( $internal_net->bits() < 16 && isenabled( $Config{'general'}{'caching'} ) ) {
            add_problem( $WARN, "network $internal_net is larger than a /16 - you must disable general.caching!" );
        }
        $internal_total += $internal_net->size();
    }

    # test to do in ARP mode
    nameservers();

}

=item mode_vlan

Configuration validation for VLAN Isolation mode

=cut
sub mode_vlan {

    # make sure trapping.passthrough=proxy if network.mode is set to vlan
    if ( $Config{'trapping'}{'passthrough'} eq 'iptables' ) {
        add_problem( $FATAL, "Please set trapping.passthrough to proxy while using VLAN isolation mode" );
    }

    # make sure that skip_mode is disabled in VLAN isolation
    if ( !isdisabled($Config{'registration'}{'skip_mode'}) ) {
        add_problem( $FATAL, "registration skip_mode is currently incompatible with VLAN isolation" );
    }

    # make sure that expire_mode session is disabled in VLAN isolation
    if (lc($Config{'registration'}{'expire_mode'}) eq 'session') {
        add_problem( $FATAL, 
            "automatic node expiration mode ".$Config{'registration'}{'expire_mode'} . " " .
            "is currently incompatible with VLAN isolation"
        );
    }

    # make sure that networks.conf is not empty when vlan.dhcpd
    # is enabled
    if ((isenabled($Config{'vlan'}{'dhcpd'})) && ((!-e "$conf_dir/networks.conf") || (-z "$conf_dir/networks.conf"))) {
        add_problem( $FATAL, "networks.conf cannot be empty when vlan.dhcpd is enabled" );
    }

    # make sure that networks.conf is not empty when vlan.named
    # is enabled
    if ((isenabled($Config{'vlan'}{'named'})) && ((!-e "$conf_dir/networks.conf") || (-z "$conf_dir/networks.conf"))) {
        add_problem( $FATAL, "networks.conf cannot be empty when vlan.named is enabled" );
    }

}

=item mode_dhcp

Validation for the DHCP mode

=cut
sub mode_dhcp {

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
        add_problem( $FATAL, "missing dhcp scope information" );
    }

    foreach my $scope (@dhcp_scopes) {
        if (!defined $Config{ 'scope ' . $scope }{'network'}
            || !defined $Config{ 'scope ' . $scope }{'gateway'}
            || !defined $Config{ 'scope ' . $scope }{'range'} ) {
                add_problem( $FATAL, "incomplete dhcp scope information for $scope" );
        }

        my $found = 0;
        foreach my $int (@internal_nets) {
            if ( $Config{ 'interface ' . $int->tag('int') }{'ip'} eq $Config{ 'scope ' . $scope }{'gateway'} ) {
                $found = 1;
                next;
            }
        }
        if ( !$found ) {
            add_problem( $WARN, 
                "dhcp scope $scope gateway ($Config{'scope '.$scope}{'gateway'}) is not bound to internal interface"
            );
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

    # test to do in DHCP mode
    nameservers();

}

=item database

database check

=cut
sub database {

    try {

        # make sure pid 1 exists
        require pf::person;
        if ( !pf::person::person_exist(1) ) {
            add_problem( $FATAL, "person user id 1 must exist - please reinitialize your database" );
        }

    } catch {
        if ($_ =~ /unable to connect to database/) {
            add_problem( 
                $FATAL, 
                "Unable to connect to your database. " 
                . "Please verify your connection settings in conf/pf.conf and make sure that it is started."
            );
        } else {
            add_problem( $FATAL, "Unexpected database problem: $_" );
        }
    };

}

=item web_admin

Web Administration interface checks

=cut
sub web_admin {

    # make sure admin port exists
    if ( !$Config{'ports'}{'admin'} ) {
        add_problem( $FATAL, "please set the web admin port in pf.conf (ports.admin)" );
    }

}

=item nameservers

We need DNS Servers defined.
Applies only to arp and dhcp mode.

=cut
sub nameservers {

    # make sure dns servers exist
    if ( !$Config{'general'}{'dnsservers'} ) {
        add_problem( $FATAL,
            "please set the dns servers list in pf.conf (general.dnsservers). " . 
            "If this is not set users in isolation will not be able to resolve hostnames, " . 
            "and will not able to reach PacketFence!"
        );
    }

}

=item registration

Registration configuration sanity

=cut
sub registration {

    # warn when scan.registration=enabled and trapping.registration=disabled
    if ( isenabled( $Config{'scan'}{'registration'} ) && isdisabled( $Config{'trapping'}{'registration'} ) ) {
        add_problem( $WARN, "scan.registration is enabled but trapping.registration is not ... this is strange!" );
    }

    # registration.skip_mode validation
    if ( $Config{'registration'}{'skip_mode'} eq "deadline" && !$Config{'registration'}{'skip_deadline'} ) {
        add_problem( $FATAL,
            "pf.conf value registration.skip_deadline is mal-formed or null! " . 
            "(format should be that of the 'date' command)"
        );
    } elsif ( $Config{'registration'}{'skip_mode'} eq "windows" && !$Config{'registration'}{'skip_window'} ) {
        add_problem( $FATAL, "pf.conf value registration.skip_window is not defined!" );
    }

    # registration.expire_mode validation
    if ( $Config{'registration'}{'expire_mode'} eq "deadline" && !$Config{'registration'}{'expire_deadline'} ) {
        add_problem( $FATAL,
            "pf.conf value registration.expire_deadline is mal-formed or null! " . 
            "(format should be that of the 'date' command)"
        );
    } elsif ( $Config{'registration'}{'expire_mode'} eq "window" && !$Config{'registration'}{'expire_window'} ) {
        add_problem( $FATAL, "pf.conf value registration.expire_window is not defined!" );
    }

}

sub is_config_documented {

    #compare configuration with documentation
    tie my %myconfig, 'Config::IniFiles', (
        -file   => $config_file,
        -import => Config::IniFiles->new( -file => $default_config_file )
    );
    tie my %documentation, 'Config::IniFiles', ( -file => $conf_dir . "/documentation.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        my $message = join( "\n", @errors ) . "\n";
        add_problem( $FATAL, "problem reading documentation.conf. Error: $message" );
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
                    add_problem( $FATAL,
                        "pf.conf value $group\.$item must be one of the following: "
                        . $documentation{$section}{'options'}
                    );
                }
            } elsif ( $type eq "time" ) {
                if ( $myconfig{$group}{$item} !~ /\d+[smhdw]$/ ) {
                    add_problem( $FATAL,
                        "pf.conf value $group\.$item does not explicity define interval (eg. 7200s, 120m, 2h) " .
                        "- please define it before running packetfence"
                    );
                }
            } elsif ( $type eq "multi" ) {
                my @selectedOptions = split( /\s*,\s*/, $myconfig{$group}{$item} );
                my @availableOptions = split( /\s*[;\|]\s*/, $documentation{$section}{'options'} );
                foreach my $currentSelectedOption (@selectedOptions) {
                    if ( grep(/^$currentSelectedOption$/, @availableOptions) == 0 ) {
                        add_problem( $FATAL,
                            "pf.conf values for $group\.$item must be among the following: " .
                            $documentation{$section}{'options'} .  " but you used $currentSelectedOption. " .
                            "If you are sure of this choice, please update conf/documentation.conf"
                        );
                    }
                }
            }
        } elsif ( $Config{$group}{$item} ne "0" ) {
            add_problem( $FATAL, "pf.conf value $group\.$item is not defined!" );
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
                add_problem( $FATAL, 
                    "unknown configuration parameter $section.$item ".
                    "if you added the parameter yourself make sure it is present in conf/documentation.conf"
                );
            }
        }
    }

}

=item extensions

Performs version checking of the extension points.

=cut
sub extensions {

    try {
        require pf::vlan::custom;
        if (!defined(pf::vlan::custom->VERSION())) {
            add_problem( $FATAL,
                "VLAN Extension point (pf::vlan::custom) VERSION is not defined. Did you read the UPGRADE document?"
            );
        } elsif ($VLAN_API_LEVEL > pf::vlan::custom->VERSION()) {
            add_problem( $FATAL,
                "VLAN Extension point (pf::vlan::custom) is not at the correct API level. " .
                "Did you read the UPGRADE document?"
            );
        }
    } catch {
        add_problem( $FATAL, "Uncaught exception while trying to identify VLAN extension version: $_" );
    };

    # we wrap in a try/catch because we might trap exceptions if pf::vlan::custom is not to the appropriate level
    try {
        require pf::radius::custom;
        if (!defined(pf::radius::custom->VERSION())) {
            add_problem( $FATAL,
                "RADIUS Extension point (pf::radius::custom) VERSION is not defined. " . 
                "Did you read the UPGRADE document?"
            );
        } elsif ($RADIUS_API_LEVEL > pf::radius::custom->VERSION()) {
            add_problem( $FATAL,
                "RADIUS Extension point (pf::radius::custom) is not at the correct API level. " .
                "Did you read the UPGRADE document?"
            );
        }
    } catch {
        # we ignore "version check failed" or "version x required"
        # as it means that pf::vlan::custom's version is not good which we already catched above
        if ($_ !~ /(?:version check failed)|(?:version .+ required)/) {
            add_problem( $FATAL, "Uncaught exception while trying to identify RADIUS extension version: $_" );
        }
    };

}

=item permissions

Checking some important permissions

=cut
sub permissions {

    # pfcmd needs to be setuid / setgid and 
    # TODO once #1087 is fixed, promote to fatal or remove need for setuid/setgid
    my (undef, undef, $pfcmd_mode, undef, $pfcmd_owner, $pfcmd_group) = stat($bin_dir . "/pfcmd");
    if (!($pfcmd_mode & S_ISUID && $pfcmd_mode & S_ISGID)) {
        add_problem( $WARN, "pfcmd needs setuid and setgid bit set to run properly. Fix with chmod ug+s pfcmd" );
    }
    # pfcmd needs to be owned by root (owner id 0 / group id 0) 
    # TODO once #1087 is fixed, promote to fatal or remove need for setuid/setgid
    if ($pfcmd_owner || $pfcmd_group) {
        add_problem( $WARN, "pfcmd needs to be owned by root. Fix with chown root:root pfcmd" );
    }

    # TODO verify log files ownership (issue #1191)

}

=item apache

Apache related tests

=cut
sub apache {

    # we dynamically adjust apache's configuration based on total system memory
    # we will first here test if we can figure it out
    my $total_ram = get_total_system_memory();
    if (!defined($total_ram)) {
        add_problem( 
            $WARN, 
            "Unable to find out how much system memory is available. "
            . "We'll assume you have 2 Gigabyte. "
            . "Please report an issue."
        );
    }

}

=item violations

Checking for violations configurations

=cut
sub violations {
    my %violations_conf;
    tie %violations_conf, 'Config::IniFiles', ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        add_problem( $FATAL, "Error reading violations.conf");
    }

    my %violations = pf::services::class_set_defaults(%violations_conf);    

    foreach my $violation ( keys %violations ) {

        # parse triggers if they exist
        if ( defined $violations{$violation}{'trigger'} ) {
            try { 
                # TODO we are parsing triggers both on checkup and when we parse the configuration on startup
                # we probably can do something smarter here (but can't find right maintenance / efficiency balance now)
                parse_triggers($violations{$violation}{'trigger'});
            } catch {
                add_problem($WARN, "Violation $violation is ignored: $_");
            };
        }
    }
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

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
