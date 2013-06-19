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
use pf::log;
use pf::config::cached;
use pf::util;
use pf::file_paths;
use Data::Swap;
use Time::HiRes qw(gettimeofday);
use Benchmark qw(:all);
use List::Util qw(first);

our ($singleton, %SwitchConfig, $switches_overlay_cached_config, $switches_cached_config);

$switches_cached_config = pf::config::cached->new(
    -file => $switches_config_file,
    -allowempty => 1,
    -default => 'default',
);

$switches_overlay_cached_config = pf::config::cached->new(
    -file => $switches_overlay_file,
    -allowempty => 1,
    -import => $switches_cached_config,
    -default => 'default',
    -onfilereload => [
        on_switches_reload => sub  {
            my ($config, $name) = @_;
            $config->toHash(\%SwitchConfig);
            $config->cleanupWhitespace(\%SwitchConfig);
            foreach my $switch (values %SwitchConfig) {
                # transforming uplink and inlineTrigger to arrays
                foreach my $key (qw(uplink inlineTrigger)) {
                    my $value = $switch->{$key} || "";
                    $switch->{$key} = [split /\s*,\s*/,$value ];
                }
                # transforming vlans and roles to hashes
                my %merged = ( Vlan => {}, Role => {});
                foreach my $key ( grep { /(Vlan|Role)$/ } keys %{$switch}) {
                    next unless my $value = $switch->{$key};
                    if (my ($type_key,$type) = ($key =~ /^(.+)(Vlan|Role)$/)) {
                        $merged{$type}{$type_key} = $value;
                    }
                }
                $switch->{roles} = $merged{Role};
                $switch->{vlans} = $merged{Vlan};
                $switch->{VoIPEnabled} =  ($switch->{VoIPEnabled} =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0);
                $switch->{mode} =  lc($switch->{mode});
                $switch->{'wsUser'} ||= $switch->{'htaccessUser'};
                $switch->{'wsPwd'}  ||= $switch->{'htaccessPwd'} || '';
                foreach my $cli_default (qw(EnablePwd Pwd User)) {
                    $switch->{"cli${cli_default}"}  ||= $switch->{"telnet${cli_default}"};
                }
                foreach my $snmpDefault (qw(communityRead communityTrap communityWrite version)) {
                    my $snmpkey = "SNMP" . ucfirst($snmpDefault);
                    $switch->{$snmpkey}  ||= $switch->{$snmpDefault};
                }
            }
            $SwitchConfig{'127.0.0.1'} = { %{$SwitchConfig{default}}, type => 'PacketFence', mode => 'production', uplink => ['dynamic'], SNMPVersionTrap => '1', SNMPCommunityTrap => 'public'};
            $config->cache->set("SwitchConfig",\%SwitchConfig);
        },
    ],
    -oncachereload => [
        on_cached_overlay_reload => sub  {
            my ($config, $name) = @_;
            my $data = $config->cache->get("SwitchConfig");
            if($data) {
                %SwitchConfig = %$data;
            }
        },
    ]
);

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
    my $logger = get_logger();
    $logger->debug("instantiating new SwitchFactory object");
    my ( $class, %argv ) = @_;
    return bless \$singleton, $class;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = get_logger();
    my ( $this, @requestedSwitches ) = @_;
    my $requestedSwitch = first {exists $SwitchConfig{$_} } @requestedSwitches;
    unless ($requestedSwitch) {
        $logger->error("ERROR ! Unknown switch(es) ". join(" ",@requestedSwitches));
        return 0;
    }
    my $switch_data = $SwitchConfig{$requestedSwitch};

    # find the module to instantiate
    my $type;
    if ($requestedSwitch ne 'default') {
        $type = "pf::SNMP::" . $switch_data->{'type'};
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

    $logger->debug("creating new $type object");
    return $type->new( 'ip' => $requestedSwitch, %$switch_data);
}

sub config {
    my %temp = %SwitchConfig;
    return \%temp;
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
