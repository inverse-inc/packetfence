package pf::SwitchFactory;

=head1 NAME

pf::SwitchFactory - Object oriented factory to instantiate objects

=head1 SYNOPSIS

The pf::SwitchFactory module implements an object oriented factory to
instantiate objects of type pf::Switch or subclasses of this. This module
is meant to read in a switches.conf configuration file containing all
the necessary information needed to actually instantiate the objects.

=cut

use strict;
use warnings;

use Carp;
use UNIVERSAL::require;
use pf::log;
use pf::util;
use pf::freeradius;
use pf::file_paths;
use Time::HiRes qw(gettimeofday);
use Benchmark qw(:all);
use List::Util qw(first);
use pf::CHI;
use pfconfig::cached_hash;
use pf::factory::config;

my %SwitchConfig = pf::factory::config->new('cached_hash', 'config::Switch');

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

=item hasId

Checks if switch id exists

=cut

sub hasId { exists $SwitchConfig{$_[0]} }

=item instantiate - create new pf::Switch (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut

sub instantiate {
    my $logger = get_logger();
    my ( $self, $switchRequest ) = @_;
    my @requestedSwitches;
    my $requestedSwitch;
    my $switch_ip;
    my $switch_mac;
    my $switch_overlay_cache = pf::CHI->new(namespace => 'switch.overlay');

    pfconfig::timeme::timeme('building stuff', sub {
    if(ref($switchRequest) eq 'HASH') {
        if(exists $switchRequest->{switch_mac} && defined $switchRequest->{switch_mac}) {
            $switch_mac = $switchRequest->{switch_mac};
            push @requestedSwitches,$switch_mac;
        }
        if(exists $switchRequest->{switch_ip} && defined $switchRequest->{switch_ip}) {
            $switch_ip = $switchRequest->{switch_ip};
            push @requestedSwitches,$switch_ip;
        }
    } else {
        @requestedSwitches = ($switchRequest);
        if(valid_ip($switchRequest)) {
            $switch_ip = $switchRequest;
        } elsif (valid_mac($switchRequest)) {
            $switch_mac = $switchRequest;
        }
    }
    });

    my $switch_data;
    foreach my $search (@requestedSwitches){
        if($SwitchConfig{$search}){
            $requestedSwitch = $search;
            $switch_data = $SwitchConfig{$search};
            last;
        }
    }
    unless (defined($requestedSwitch)) {
        $logger->error("WARNING ! Unknown switch(es) ". join(" ",@requestedSwitches));
        return 0;
    }


    if( $switch_mac && $requestedSwitch eq $switch_mac && ref($switchRequest) eq 'HASH' && !defined ($switch_data->{controllerIp}) ) {
        my $switch = $switch_overlay_cache->get($switch_mac) || {};
        my $controllerIp = $switchRequest->{controllerIp};
        if($controllerIp && (  !defined $switch->{controllerIp} || $controllerIp ne $switch->{controllerIp} )) {
#            $switch_overlay_config->remove($switch->{controllerIp}) if defined $switch->{controllerIp};
            $switch_overlay_cache->set(
                $switch_mac,
                {
                    controllerIp => $controllerIp,
                    ip => $switch_ip
                }
            );
        }
    }


    my $switchOverlay;
    pfconfig::timeme::timeme('overlayget', sub {
    # find the module to instantiate
    $switchOverlay = $switch_overlay_cache->get($requestedSwitch) || {};
    });
    my $type;
    pfconfig::timeme::timeme('type import', sub {
    if ($requestedSwitch ne 'default') {
        $type = "pf::Switch::" . $switch_data->{'type'};
    } else {
        $type = "pf::Switch";
    }
    $type = untaint_chain($type);
    # load the module to instantiate
    if ( !(eval "$type->require()" ) ) {
        $logger->error("Can not load perl module for switch $requestedSwitch, type: $type. "
            . "Either the type is unknown or the perl module has compilation errors. "
            . "Read the following message for details: $@");
        return 0;
    }
    });

    my $result;
    pfconfig::timeme::timeme('creating', sub {
    $logger->debug("creating new $type object");
    $result = $type->new(
         id => $requestedSwitch,
         ip => $switch_ip,
         switchIp => $switch_ip,
         switchMac => $switch_mac,
         %$switch_data,
         %$switchOverlay,
    );
    });
    return $result;
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
