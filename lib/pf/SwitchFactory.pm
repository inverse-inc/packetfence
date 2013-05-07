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
use UNIVERSAL::require;
use Log::Log4perl;

use pf::config;
use pf::config::cached;
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
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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
        $this->{_configFile} = $switches_config_file;
    }

    my $cached_config  = pf::config::cached->new( -file => $this->{_configFile}, -allowempty => 1 );
    $this->{_cached_config} = $cached_config;
    $this->_fixupConfig();
    $cached_config->addReloadCallbacks( 'reload_switch_factory' =>  sub { $this->_fixupConfig(); });

    return $this;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $this, $requestedSwitch ) = @_;
    my %SwitchConfig = %{ $this->config };
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
    $type = untaint_chain($type);
    # load the module to instantiate
    if ( !(eval "$type->require()" ) ) {
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

    # transforming vlans and roles to hashes
    my %vlans = ();
    my %roles = ();
    foreach my $key (keys %{$SwitchConfig{$requestedSwitch}}) {
        next unless $SwitchConfig{$requestedSwitch}{$key};
        if (my ($vlan) = $key =~ m/^(\w+)Vlan$/) {
            $vlans{$vlan} = $SwitchConfig{$requestedSwitch}{$key};
        }
        elsif (my ($role) = $key =~ m/^(\w+)Role$/) {
            $roles{$role} = $SwitchConfig{$requestedSwitch}{$key};
        }
    }
    foreach my $key (keys %{$SwitchConfig{default}}) {
        next unless $SwitchConfig{default}{$key};
        if (my ($vlan) = $key =~ m/^(\w+)Vlan$/) {
            $vlans{$vlan} = $SwitchConfig{default}{$key} unless ($vlans{$vlan});
        }
        elsif (my ($role) = $key =~ m/^(\w+)Role$/) {
            $roles{$role} = $SwitchConfig{default}{$key} unless ($roles{$role});
        }
    }

    # transforming inlineTrigger to array
    my @inlineTrigger = ();
    if ( $SwitchConfig{$requestedSwitch}{'inlineTrigger'} || $SwitchConfig{'default'}{'inlineTrigger'} ) {
        my @_inlineTrigger_tmp =
            split(/,/,($SwitchConfig{$requestedSwitch}{'inlineTrigger'} || $SwitchConfig{'default'}{'inlineTrigger'}));

        foreach my $_tmp (@_inlineTrigger_tmp) {
            $_tmp =~ s/ //g;
            push @inlineTrigger, $_tmp;
        }
    }

    $logger->debug("creating new $type object");
    return $type->new(
        '-uplink'    => \@uplink,
        '-vlans'     => \%vlans,
        '-roles'     => \%roles,
        '-inlineTrigger' => \@inlineTrigger,
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
        '-macSearchesMaxNb' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesMaxNb'}
                || $SwitchConfig{'default'}{'macSearchesMaxNb'}
        ),
        '-macSearchesSleepInterval' => (
                   $SwitchConfig{$requestedSwitch}{'macSearchesSleepInterval'}
                || $SwitchConfig{'default'}{'macSearchesSleepInterval'}
        ),
        '-mode' => lc( ($SwitchConfig{$requestedSwitch}{'mode'} || $SwitchConfig{'default'}{'mode'}) ),
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
        '-VoIPEnabled' => (
            (          $SwitchConfig{$requestedSwitch}{'VoIPEnabled'}
                    || $SwitchConfig{'default'}{'VoIPEnabled'}
            ) =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0
        ),
        '-deauthMethod' => (
                   $SwitchConfig{$requestedSwitch}{'deauthMethod'}
                || $SwitchConfig{'default'}{'deauthMethod'}
        ),
    );
}

sub _fixupConfig {
    my ($this) = @_;
    my %config;
    my $cached_config = $this->{_cached_config};
    $cached_config->toHash(\%config);
    $cached_config->cleanupWhitespace(\%config);
    $config{'127.0.0.1'} = {type => 'PacketFence', mode => 'production', uplink => 'dynamic', SNMPVersionTrap => '1', SNMPCommunityTrap => 'public'};
    $this->{_config} = \%config;
}

sub config {
    my ($this) = @_;
    return $this->{_config};
}

=back

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
