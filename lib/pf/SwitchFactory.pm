package pf::SwitchFactory;

=head1 NAME

pf::SwitchFactory - Object oriented factory to instantiate objects

=head1 SYNOPSIS

The pf::SwitchFactory module implements an object oriented factory to
instantiate objects of type pf::SNMP or subclasses of this. This module
is meant to read in a switches.conf configuration file containing all
the necessary information needed to actually instantiate the objects.

=cut

use strict;
use warnings;

use Carp;
use Config::IniFiles;
use UNIVERSAL::require;
use Log::Log4perl;

use pf::config;
use pf::util;

my $singleton;

=head1 METHODS

=over

=item getInstance

Get the singleton instance of switchFactory. Create it if it doesn't exist.

=cut
sub getInstance {
    my ( $class, %args ) = @_;

    if (!defined($singleton)) {
        $singleton = $class->new(%args);
    }

    return $singleton;
}

=item new

Create a switchFactory instance

=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("instantiating new SwitchFactory object");
    my ( $class, %argv ) = @_;
    my $this = bless {
        '_configFile' => undef,
        '_config'     => undef
    }, $class;

    foreach ( keys %argv ) {
        if (/^-?configFile$/i) {
            $this->{_configFile} = $argv{$_};
        }
    }

    if ( !defined( $this->{_configFile} ) ) {
        $this->{_configFile} = $conf_dir.'/switches.conf';
    }

    $this->readConfig();

    return $this;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    my ( $this, $requestedSwitch ) = @_;
    my %SwitchConfig = %{ $this->{_config} };
    if ( !exists $SwitchConfig{$requestedSwitch} ) {
        $logger->error("ERROR ! Unknown switch $requestedSwitch");
        return 0;
    }

    # find the module to instantiate
    my $type;
    if ($requestedSwitch ne 'default') {
        $type = "pf::SNMP::" . ($SwitchConfig{$requestedSwitch}{'type'} || $SwitchConfig{'default'}{'type'});
    } else {
        $type = "pf::SNMP";
    }
    # load the module to instantiate
    if (!$type->require()) {
        $logger->error("Can not load perl module for switch $requestedSwitch, type: $type. "
            . "Either the type is unknown or the perl module has compilation errors. "
            . "Read the following message for details: $@");
        return 0;
    }

    # transforming uplinks to array
    my @uplink = ();
    if (   $SwitchConfig{$requestedSwitch}{'uplink'}
        || $SwitchConfig{'default'}{'uplink'} )
    {

        my @_uplink_tmp = split(
            /,/,
            (          $SwitchConfig{$requestedSwitch}{'uplink'}
                    || $SwitchConfig{'default'}{'uplink'}
            )
        );
        foreach my $_tmp (@_uplink_tmp) {
            $_tmp =~ s/ //g;
            push @uplink, $_tmp;
        }
    }

    # transforming vlans to array
    my @vlans      = ();
    my @_vlans_tmp = split(
        /,/,
        (          $SwitchConfig{$requestedSwitch}{'vlans'}
                || $SwitchConfig{'default'}{'vlans'}
        )
    );
    foreach my $_tmp (@_vlans_tmp) {
        $_tmp =~ s/ //g;
        push @vlans, $_tmp;
    }

    my $custom_vlan_assignments_ref = $this->_customVlanExpansion($requestedSwitch, %SwitchConfig);

    $logger->debug("creating new $type object");
    return $type->new(
        %$custom_vlan_assignments_ref,
        '-uplink'    => \@uplink,
        '-vlans'     => \@vlans,
        '-guestVlan' => (
                   $SwitchConfig{$requestedSwitch}{'guestVlan'}
                || $SwitchConfig{'default'}{'guestVlan'}
        ),
        '-wsUser' => (
            $SwitchConfig{$requestedSwitch}{'wsUser'}
            || $SwitchConfig{$requestedSwitch}{'htaccessUser'}
            || $SwitchConfig{'default'}{'wsUser'}
            || $SwitchConfig{'default'}{'htaccessUser'}
        ),
        '-wsPwd' => (
            $SwitchConfig{$requestedSwitch}{'wsPwd'}
            || $SwitchConfig{$requestedSwitch}{'htaccessPwd'}
            || $SwitchConfig{'default'}{'wsPwd'}
            || $SwitchConfig{'default'}{'htaccessPwd'}
            || ''
        ),
        '-wsTransport' => (
            $SwitchConfig{$requestedSwitch}{'wsTransport'}
            || $SwitchConfig{'default'}{'wsTransport'}
            || 'http'
        ),
        '-radiusSecret' => (
            $SwitchConfig{$requestedSwitch}{'radiusSecret'}
            || $SwitchConfig{'default'}{'radiusSecret'}
        ),
        '-controllerIp' => (
            $SwitchConfig{$requestedSwitch}{'controllerIp'}
            || $SwitchConfig{'default'}{'controllerIp'}
        ),
        '-ip'            => $requestedSwitch,
        '-isolationVlan' => (
                   $SwitchConfig{$requestedSwitch}{'isolationVlan'}
                || $SwitchConfig{'default'}{'isolationVlan'}
        ),
        '-macDetectionVlan' => (
                   $SwitchConfig{$requestedSwitch}{'macDetectionVlan'}
                || $SwitchConfig{'default'}{'macDetectionVlan'}
        ),
        '-macSearchesMaxNb' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesMaxNb'}
                || $SwitchConfig{'default'}{'macSearchesMaxNb'}
        ),
        '-macSearchesSleepInterval' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesSleepInterval'}
                || $SwitchConfig{'default'}{'macSearchesSleepInterval'}
        ),
        '-mode' => lc( ($SwitchConfig{$requestedSwitch}{'mode'} || $SwitchConfig{'default'}{'mode'}) ),
        '-normalVlan' => (
                   $SwitchConfig{$requestedSwitch}{'normalVlan'}
                || $SwitchConfig{'default'}{'normalVlan'}
        ),
        '-registrationVlan' => (
                   $SwitchConfig{$requestedSwitch}{'registrationVlan'}
                || $SwitchConfig{'default'}{'registrationVlan'}
        ),
        '-SNMPAuthPasswordRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordRead'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordRead'}
        ),
        '-SNMPAuthPasswordTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordTrap'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordTrap'}
        ),
        '-SNMPAuthPasswordWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordWrite'}
                || $SwitchConfig{'default'}{'SNMPAuthPasswordWrite'}
        ),
        '-SNMPAuthProtocolRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolRead'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolRead'}
        ),
        '-SNMPAuthProtocolTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolTrap'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolTrap'}
        ),
        '-SNMPAuthProtocolWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolWrite'}
                || $SwitchConfig{'default'}{'SNMPAuthProtocolWrite'}
        ),
        '-SNMPCommunityRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityRead'}
                || $SwitchConfig{$requestedSwitch}{'communityRead'}
                || $SwitchConfig{'default'}{'SNMPCommunityRead'}
                || $SwitchConfig{'default'}{'communityRead'}
        ),
        '-SNMPCommunityTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityTrap'}
                || $SwitchConfig{$requestedSwitch}{'communityTrap'}
                || $SwitchConfig{'default'}{'SNMPCommunityTrap'}
                || $SwitchConfig{'default'}{'communityTrap'}
        ),
        '-SNMPCommunityWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPCommunityWrite'}
                || $SwitchConfig{$requestedSwitch}{'communityWrite'}
                || $SwitchConfig{'default'}{'SNMPCommunityWrite'}
                || $SwitchConfig{'default'}{'communityWrite'}
        ),
        '-SNMPPrivPasswordRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordRead'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordRead'}
        ),
        '-SNMPPrivPasswordTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordTrap'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordTrap'}
        ),
        '-SNMPPrivPasswordWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordWrite'}
                || $SwitchConfig{'default'}{'SNMPPrivPasswordWrite'}
        ),
        '-SNMPPrivProtocolRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolRead'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolRead'}
        ),
        '-SNMPPrivProtocolTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolTrap'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolTrap'}
        ),
        '-SNMPPrivProtocolWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolWrite'}
                || $SwitchConfig{'default'}{'SNMPPrivProtocolWrite'}
        ),
        '-SNMPUserNameRead' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameRead'}
                || $SwitchConfig{'default'}{'SNMPUserNameRead'}
        ),
        '-SNMPUserNameTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameTrap'}
                || $SwitchConfig{'default'}{'SNMPUserNameTrap'}
        ),
        '-SNMPUserNameWrite' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPUserNameWrite'}
                || $SwitchConfig{'default'}{'SNMPUserNameWrite'}
        ),
        '-SNMPVersion' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPVersion'}
                || $SwitchConfig{$requestedSwitch}{'version'}
                || $SwitchConfig{'default'}{'SNMPVersion'}
                || $SwitchConfig{'default'}{'version'}
        ),
        '-SNMPEngineID' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPEngineID'}
                || $SwitchConfig{'default'}{'SNMPEngineID'}
        ),
        '-SNMPVersionTrap' => (
                   $SwitchConfig{$requestedSwitch}{'SNMPVersionTrap'}
                || $SwitchConfig{'default'}{'SNMPVersionTrap'}
        ),
        '-cliEnablePwd' => (
                   $SwitchConfig{$requestedSwitch}{'cliEnablePwd'}
                || $SwitchConfig{$requestedSwitch}{'telnetEnablePwd'}
                || $SwitchConfig{'default'}{'cliEnablePwd'}
                || $SwitchConfig{'default'}{'telnetEnablePwd'}
        ),
        '-cliPwd' => (
                   $SwitchConfig{$requestedSwitch}{'cliPwd'}
                || $SwitchConfig{$requestedSwitch}{'telnetPwd'}
                || $SwitchConfig{'default'}{'cliPwd'}
                || $SwitchConfig{'default'}{'telnetPwd'}
        ),
        '-cliUser' => (
                   $SwitchConfig{$requestedSwitch}{'cliUser'}
                || $SwitchConfig{$requestedSwitch}{'telnetUser'}
                || $SwitchConfig{'default'}{'cliUser'}
                || $SwitchConfig{'default'}{'telnetUser'}
        ),
        '-cliTransport' => (
                   $SwitchConfig{$requestedSwitch}{'cliTransport'}
                || $SwitchConfig{'default'}{'cliTransport'}
                || 'Telnet'
        ),
        '-voiceVlan' => (
                   $SwitchConfig{$requestedSwitch}{'voiceVlan'}
                || $SwitchConfig{'default'}{'voiceVlan'}
        ),
        '-VoIPEnabled' => (
            (          $SwitchConfig{$requestedSwitch}{'VoIPEnabled'}
                    || $SwitchConfig{'default'}{'VoIPEnabled'}
            ) =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0
        ),
        '-roles' => (
                   $SwitchConfig{$requestedSwitch}{'roles'}
                || $SwitchConfig{'default'}{'roles'}
        ),
        '-deauthMethod' => (
                   $SwitchConfig{$requestedSwitch}{'deauthMethod'}
                || $SwitchConfig{'default'}{'deauthMethod'}
        ),
    );
}

=item readConfig - read configuration file

  $switchFactory->readConfig();

=cut

sub readConfig {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("reading config file $this->{_configFile}");
    if ( !defined( $this->{_configFile} ) ) {
        croak "Config file has not been defined\n";
    }
    my %SwitchConfig;
    if ( !-e $this->{_configFile} ) {
        croak "Config file " . $this->{_configFile} . " cannot be read\n";
    }
    tie %SwitchConfig, 'Config::IniFiles', ( -file => $this->{_configFile} );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        croak "Error reading config file: " . join( "\n", @errors ) . "\n";
    }

    #remove trailing spaces..
    foreach my $section ( tied(%SwitchConfig)->Sections ) {
        foreach my $key ( keys %{ $SwitchConfig{$section} } ) {
            $SwitchConfig{$section}{$key} =~ s/\s+$//;
        }
    }
    %{ $this->{_config} } = %SwitchConfig;

    return 1;
}

sub _customVlanExpansion {
    my ($this, $requestedSwitch, %SwitchConfig) = @_;

    my %custom_vlan_assignments;
    for my $custom_nb (0 .. 99) {
        my $vlan;
        # switch specific VLAN first
        if (defined($SwitchConfig{$requestedSwitch}{'customVlan'.$custom_nb})) {
            $vlan = $SwitchConfig{$requestedSwitch}{'customVlan'.$custom_nb};
        }
        # then default section
        elsif (defined($SwitchConfig{'default'}{'customVlan'.$custom_nb})) {
            $vlan = $SwitchConfig{'default'}{'customVlan'.$custom_nb};
        }

        # we'll assign the customVlanXX value only if it exists
        $custom_vlan_assignments{'-customVlan' . $custom_nb} = $vlan if (defined($vlan));
    }
    return \%custom_vlan_assignments;
}

=back

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2012 Inverse inc.

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
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
