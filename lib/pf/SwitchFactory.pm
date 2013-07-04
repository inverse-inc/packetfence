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
use Time::HiRes qw(gettimeofday);
use Benchmark qw(:all);
use List::Util qw(first);
use pf::ConfigStore::Switch;
use pf::ConfigStore::SwitchOverlay;

our ($singleton);

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
    my $self;
    return bless \$self, $class;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = get_logger();
    my ( $this, $switchId ) = @_;
    my @requestedSwitches;
    my $requestedSwitch;
    my $switch_ip;
    my $switch_mac;
    my $switch_overlay = pf::ConfigStore::SwitchOverlay->new;
    my $switch_config = pf::ConfigStore::Switch->new;

    if(ref($switchId) eq 'HASH') {
        if(exists $switchId->{switch_mac} && defined $switchId->{switch_mac}) {
            $switch_mac = $switchId->{switch_mac};
            push @requestedSwitches,$switch_mac;
        }
        if(exists $switchId->{switch_ip} && defined $switchId->{switch_ip}) {
            $switch_ip = $switchId->{switch_ip};
            push @requestedSwitches,$switch_ip;
        }
    } else {
        @requestedSwitches = ($switchId);
        if(valid_ip($switchId)) {
            $switch_ip = $switchId;
        } elsif (valid_mac($switchId)) {
            $switch_mac = $switchId;
        }
    }

    if($switch_config->hasId($switch_mac)) {
        my $switch = $switch_config->read($switch_mac);
        my $controllerIp = $switchId->{controllerIp};
        if($controllerIp && (  !defined $switch->{_controllerIp} || $controllerIp ne $switch->{_controllerIp} )) {
            $switch_overlay->remove($switch->{_controllerIp}) if defined $switch->{_controllerIp};
            $switch_overlay->update_or_create(
                $switch_mac,
                {
                    controllerIp => $controllerIp,
                    ip => $controllerIp
                }
            );
            $switch_overlay->copy($switch_mac, $controllerIp);
            $switch_overlay->commit();
        }
    }

    $requestedSwitch = first {exists $SwitchConfig{$_} } @requestedSwitches;
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
    return $type->new(
         id => $requestedSwitch,
         switchIp => $switch_ip,
         switchMac => $switch_mac,
         %$switch_data
    );
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
