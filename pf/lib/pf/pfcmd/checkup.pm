package pf::pfcmd::checkup;

=head1 NAME

pf::pfcmd::checkup - pfcmd's checkup tasks

=head1 DESCRIPTION

This modules holds all the tests performed by 'pfcmd checkup' which is a general configuration sanity test.

=cut

use strict;
use warnings;
use Log::Log4perl;

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

=head1 SUBROUTINES

=over

=cut

# TODO split in smaller focused subs
sub sanity_check {
    my (@services) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my %seen;

    print "Checking configuration sanity...\n";

    foreach my $service (@services) {
        my $exe = ( $Config{'services'}{$service}
                || "$install_dir/sbin/$service" );
        $logger->logdie("$exe for $service does not exist !") if ( !-e $exe );
    }

    #check the config file to make sure interfaces are fully defined
    foreach my $interface ( tied(%Config)->GroupMembers("interface") ) {
        if ( $Config{$interface}{'type'} !~ /monitor|dhcplistener/ ) {
            if (   !defined $Config{$interface}{'ip'}
                || !defined $Config{$interface}{'mask'}
                || !defined $Config{$interface}{'gateway'} )
            {
                $logger->logdie(
                    "incomplete network information for $interface ");
            }
        }
    }

 # check the Netmask objs and make sure a managed and internal interface exist
    my @tmp_nets;
    push @tmp_nets, @internal_nets;
    push @tmp_nets, @managed_nets;
    if ( !scalar(@internal_nets) ) {
        $logger->logdie("internal network(s) not defined!");
    }
    if ( scalar(@managed_nets) != 1 ) {
        $logger->logdie("please define exactly one managed interace");
    }
    foreach my $interface (@tmp_nets) {
        my $device = "interface " . $interface->tag("int");
        if (!(     $Config{$device}{'mask'}
                && $Config{$device}{'ip'}
                && $Config{$device}{'gateway'}
                && $Config{$device}{'type'}
            )
            && !$seen{$interface}
            )
        {
            $logger->logdie("incomplete network information for $device");
        }
        $seen{$interface} = 1;
    }

    if ( isenabled( $Config{'trapping'}{'detection'} ) ) {

        # make sure a monitor device is present if snort is enabled
        if ( !$monitor_int ) {
            $logger->logdie(
                "monitor interface not defined, please disable trapping.dectection or set an interface type=...,monitor in pf.conf"
            );
        }

        # make sure named pipe 'alert' is present if snort is enabled
        my $snortpipe = "$install_dir/var/alert";
        if ( !-p $snortpipe ) {
            if ( !POSIX::mkfifo( $snortpipe, oct(666) ) ) {
                $logger->logdie(
                    "snort alert pipe ($snortpipe) does not exist and unable to create it"
                );
            }
        }
    }

    if ( isenabled( $Config{'trapping'}{'detection'} ) ) {
        if ( !-x $Config{'services'}{'snort'} ) {
            $logger->logdie(
                "snort binary is not executable / does not exist!");
        }
    }

    # make sure trapping.passthrough=proxy if
    # network.mode is set to vlan
    if ( $Config{'network'}{'mode'} eq 'vlan' ) {
        if ( $Config{'trapping'}{'passthrough'} eq 'iptables' ) {
            $logger->logdie(
                "Please set trapping.passthrough to proxy while using VLAN isolation mode"
            );
        }
    }

    # make sure dhcp information is complete and valid
    # (if network.mode is set to dhcp)
    if ( $Config{'network'}{'mode'} eq 'dhcp' ) {
        my @dhcp_scopes;
        foreach my $dhcp ( tied(%Config)->GroupMembers("dhcp") ) {
            if ( defined( $Config{$dhcp}{'registered_scopes'} ) ) {
                @dhcp_scopes
                    = split( /\s*,\s*/, $Config{$dhcp}{'registered_scopes'} );
            }
            if ( defined( $Config{$dhcp}{'unregistered_scopes'} ) ) {
                push @dhcp_scopes,
                    split( /\s+/, $Config{$dhcp}{'unregistered_scopes'} );
            }
            if ( defined( $Config{$dhcp}{'isolation_scopes'} ) ) {
                push @dhcp_scopes,
                    split( /\s+/, $Config{$dhcp}{'isolation_scopes'} );
            }
        }

        if ( scalar(@dhcp_scopes) == 0 ) {
            $logger->logdie("missing dhcp scope information");
        }

        foreach my $scope (@dhcp_scopes) {
            if (   !defined $Config{ 'scope ' . $scope }{'network'}
                || !defined $Config{ 'scope ' . $scope }{'gateway'}
                || !defined $Config{ 'scope ' . $scope }{'range'} )
            {
                $logger->logdie(
                    "incomplete dhcp scope information for $scope ");
            }

            my $found = 0;
            foreach my $int (@internal_nets) {
                if ( $Config{ 'interface ' . $int->tag('int') }{'ip'} eq
                    $Config{ 'scope ' . $scope }{'gateway'} )
                {
                    $found = 1;
                    next;
                }
            }
            if ( !$found ) {
                $logger->logdie(
                    "dhcp scope $scope gateway ($Config{'scope '.$scope}{'gateway'}) is not bound to internal interface ",
                    "WARNING"
                );
            }
        }
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
    }

    # network size warning
    my $internal_total;
    foreach my $internal_net (@internal_nets) {
        if ( $internal_net->bits() < 22 ) {
            $logger->logwarn(
                "network $internal_net is larger than a /22 - you may want to consider registration queueing!"
            );
        }
        if ( $internal_net->bits() < 16
            && isenabled( $Config{'general'}{'caching'} ) )
        {
            $logger->logdie(
                "network $internal_net is larger than a /16 - you must disable general.caching!"
            );
        }
        $internal_total += $internal_net->size();
    }
    if ( $internal_total >= 1536 ) {
        $logger->logwarn(
            "internal IP space is very large - you may want to consider registration queueing!"
        );
    }

    # stuffing warning
    if ( isenabled( $Config{'arp'}{'stuffing'} ) ) {
        $logger->logwarn("ARP stuffing is enabled...this is dangerous!");
    }

    # make sure pid 1 exists
    require pf::person;
    if ( !pf::person::person_exist(1) ) {
        $logger->logdie(
            "person user id 1 must exist - please reinitialize your database"
        );
    }

    # make sure admin port exists
    if ( !$Config{'ports'}{'admin'} ) {
        $logger->logdie(
            "please set the web admin port in pf.conf (ports.admin)");
    }

    # make sure dns servers exist
    if ( !$Config{'general'}{'dnsservers'} ) {
        $logger->logdie(
            "please set the dns servers list in pf.conf (general.dnsservers).  If this is not set users in isolation will not be able to resolve hostnames, and will not able to reach PacketFence!"
        );
    }

    # make sure that skip_mode is disabled in VLAN isolation
    if (   ( lc($Config{'network'}{'mode'}) eq 'vlan' )
        && ( !isdisabled( $Config{'registration'}{'skip_mode'} ) ) )
    {
        $logger->logdie(
            "registration skip_mode is currently incompatible with VLAN isolation"
        );
    }

    # make sure that expire_mode session is disabled in VLAN isolation
    if ((lc($Config{'network'}{'mode'}) eq 'vlan') && (lc($Config{'registration'}{'expire_mode'}) eq 'session')) {

        $logger->logdie("automatic node expiration mode ".$Config{'registration'}{'expire_mode'}
            . " is currently incompatible with VLAN isolation");
    }

    # make sure that networks.conf is not empty when vlan.dhcpd
    # is enabled
    if (   ( isenabled($Config{'vlan'}{'dhcpd'}) )
        && (    ( !-e "$conf_dir/networks.conf" )
             || ( -z  "$conf_dir/networks.conf") )  )
    {
        $logger->logdie(
            "networks.conf cannot be empty when vlan.dhcpd is enabled"
        );
    }

    # make sure that networks.conf is not empty when vlan.named
    # is enabled
    if (   ( isenabled($Config{'vlan'}{'named'}) )
        && (    ( !-e "$conf_dir/networks.conf" )
             || ( -z  "$conf_dir/networks.conf") )  )
    {
        $logger->logdie(
            "networks.conf cannot be empty when vlan.named is enabled"
        );
    }

    # warn when scan.registration=enabled and trapping.registration=disabled
    if (   isenabled( $Config{'scan'}{'registration'} )
        && isdisabled( $Config{'trapping'}{'registration'} ) )
    {
        $logger->logwarn(
            "scan.registration is enabled but trapping.registration is not ... this is strang!"
        );
    }

    if ( $Config{'registration'}{'skip_mode'} eq "deadline"
        && !$Config{'registration'}{'skip_deadline'} )
    {
        $logger->logdie(
            "pf.conf value registration.skip_deadline is mal-formed or null! (format should be that of the 'date' command)"
        );
    } elsif ( $Config{'registration'}{'skip_mode'} eq "windows"
        && !$Config{'registration'}{'skip_window'} )
    {
        $logger->logdie(
            "pf.conf value registration.skip_window is not defined!");
    }

    if ( $Config{'registration'}{'expire_mode'} eq "deadline"
        && !$Config{'registration'}{'expire_deadline'} )
    {
        $logger->logdie(
            "pf.conf value registration.expire_deadline is mal-formed or null! (format should be that of the 'date' command)"
        );
    } elsif ( $Config{'registration'}{'expire_mode'} eq "window"
        && !$Config{'registration'}{'expire_window'} )
    {
        $logger->logdie(
            "pf.conf value registration.expire_window is not defined!");
    }

    #compare configuration with documentation
    tie my %myconfig, 'Config::IniFiles',
        (
        -file   => $config_file,
        -import => Config::IniFiles->new( -file => $default_config_file )
        );
    tie my %documentation, 'Config::IniFiles',
        ( -file => $conf_dir . "/documentation.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        print STDERR join( "\n", @errors ) . "\n";
        exit;
    }

    #starting with documentation vs configuration
    #i.e. make sure that pf.conf contains everything defined in
    #documentation.conf
    foreach my $section ( sort tied(%documentation)->Sections ) {
        my ( $group, $item ) = split( /\./, $section );
        my $type = $documentation{$section}{'type'};
        next
            if ( $section =~ /^(proxies|passthroughs)$/
            || $group =~ /^(dhcp|scope|interface|services)$/ );
        next if ( ( $group eq 'alerting' ) && ( $item eq 'fromaddr' ) );
        next if ( ( $group eq 'arp' )      && ( $item eq 'listendevice' ) );
        if ( defined( $Config{$group}{$item} ) ) {
            if ( $type eq "toggle" ) {
                if ( $Config{$group}{$item}
                    !~ /^$documentation{$section}{'options'}$/ )
                {
                    $logger->logdie(
                        "pf.conf value $group\.$item must be one of the following: "
                            . $documentation{$section}{'options'} );
                }
            } elsif ( $type eq "time" ) {
                if ( $myconfig{$group}{$item} !~ /\d+[smhdw]$/ ) {
                    $logger->logdie(
                        "pf.conf value $group\.$item does not explicity define interval (eg. 7200s, 120m, 2h) - please define it before running packetfence"
                    );
                }
            } elsif ( $type eq "multi" ) {
                my @selectedOptions = split( /\s*,\s*/, $myconfig{$group}{$item} );
                my @availableOptions = split( /\s*[;\|]\s*/, $documentation{$section}{'options'} );
                foreach my $currentSelectedOption (@selectedOptions) {
                    if ( grep(/^$currentSelectedOption$/, @availableOptions) == 0 ) {
                        $logger->logdie( 
                            "pf.conf values for $group\.$item must be among the following: " .
                            $documentation{$section}{'options'}
                            . " but you used $currentSelectedOption"
                            . ". If you are sure of this choice, please "
                            . " update conf/documentation.conf");
                    }
                }
            }
        } elsif ( $Config{$group}{$item} ne "0" ) {
            $logger->logdie("pf.conf value $group\.$item is not defined!");
        }
    }

    #and now the opposite way around
    #i.e. make sure that pf.conf does not contain more
    #than what is documented in documentation.conf
    foreach my $section (keys %Config) {
        next if ( ($section eq "proxies")
                  || ($section eq "passthroughs")
                  || ($section eq "")
                  || ($section =~ /^(services|interface|dhcp|scope)/)
                );
        foreach my $item  (keys %{$Config{$section}}) {
            if ( !defined( $documentation{"$section.$item"} ) ) {
                $logger->logdie("unknown configuration parameter $section.$item ".
                    "if you added the parameter yourself make sure it is present in conf/documentation.conf");
            }
        }
    }

    # performs version checking of the extension points
    require pf::radius::custom;
    if ($RADIUS_API_LEVEL > pf::radius::custom->VERSION()) {
        $logger->logdie(
            "RADIUS Extension point (pf::radius::custom) is not at the correct API level. " .
            "Did you read UPGRADE?"
        );
    }
    require pf::vlan::custom;
    if ($VLAN_API_LEVEL > pf::vlan::custom->VERSION()) {
        $logger->logdie(
            "VLAN Extension point (pf::vlan::custom) is not at the correct API level. " .
            "Did you read UPGRADE?"
        );
    }

    # TODO verify log files ownership (issue #1191)
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
