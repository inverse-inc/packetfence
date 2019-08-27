package pfconfig::namespaces::FilterEngine::SecurityEvent;
=head1 NAME

pfconfig::namespaces::FilterEngine::SecurityEvent

=cut

=head1 DESCRIPTION

pfconfig::namespaces::FilterEngine::SecurityEvent

Creates the filter engine for triggering security_events

=cut

use strict;
use warnings;
use pf::constants;
use pfconfig::namespaces::config;
use pfconfig::namespaces::config::SecurityEvents;
use pf::factory::condition::security_event;
use pf::condition::any;
use pf::condition::false;
use pf::filter;
use pf::filter_engine;
use pf::util;
use pf::log;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{child_resources} = [ 'resource::accounting_triggers', 'resource::bandwidth_expired_security_events' ];
}

sub build {
    my ($self) = @_;
    my $config_security_events = pfconfig::namespaces::config::SecurityEvents->new( $self->{cache} );
    my %SecurityEvents_Config = %{ $config_security_events->build };
    $self->{accounting_triggers} = [];
    $self->{bandwidth_expired_security_events} = [];
    $self->{invalid_triggers} = {};

    my @filters;
    while (my ($security_event, $security_event_config) = each %SecurityEvents_Config) {
        my @conditions;
        my $security_event_condition;
        next unless (isenabled($security_event_config->{enabled}) && defined($security_event_config->{trigger}));
        foreach my $trigger (split(/\s*,\s*/, $security_event_config->{trigger})) {
            my $condition;
            eval {$condition = pf::factory::condition::security_event->instantiate($trigger);};
            if ($@) {
                get_logger->error("Invalid trigger $trigger. Error was : $@");
                unless ($self->{invalid_triggers}->{$security_event}) {
                    $self->{invalid_trigger}->{$security_event} = [];
                }
                push @{$self->{invalid_triggers}->{$security_event}}, $trigger;
            }
            else {
                push @conditions, $condition;
            }

            while ($trigger =~ /(accounting::.*?)([,)&]{1}|$)/gi) {
                push @{$self->{accounting_triggers}}, {
                    trigger   => (split('::', $1))[1],
                    security_event => $security_event
                  };
            }
            if ($trigger =~ /accounting::BandwidthExpired/i) {
                push @{$self->{bandwidth_expired_security_events}}, $security_event;
            }
        }
        next if @conditions == 0;
        push @filters,
          pf::filter->new(
            {
                answer    => $security_event,
                condition => (
                      @conditions == 1
                    ? $conditions[0]
                    : pf::condition::any->new( { conditions => \@conditions } )
                )
            }
          );
    }

    return pf::filter_engine->new({ filters => \@filters });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
