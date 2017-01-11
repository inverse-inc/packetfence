package pfconfig::namespaces::FilterEngine::Violation;
=head1 NAME

pfconfig::namespaces::FilterEngine::Violation

=cut

=head1 DESCRIPTION

pfconfig::namespaces::FilterEngine::Violation

Creates the filter engine for triggering violations

=cut

use strict;
use warnings;
use pf::constants;
use pfconfig::namespaces::config;
use pfconfig::namespaces::config::Violations;
use pf::factory::condition::violation;
use pf::condition::any;
use pf::condition::false;
use pf::filter;
use pf::filter_engine;
use pf::util;
use pf::log;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{child_resources} = [ 'resource::accounting_triggers', 'resource::bandwidth_expired_violations' ];
}

sub build {
    my ($self) = @_;

    my $config_violations = pfconfig::namespaces::config::Violations->new( $self->{cache} );
    my %Violations_Config = %{ $config_violations->build };
    $self->{accounting_triggers} = [];
    $self->{bandwidth_expired_violations} = [];
    $self->{invalid_triggers} = {};

    my @filters;
    while (my ($violation, $violation_config) = each %Violations_Config) {
        my @conditions;
        my $violation_condition;
        next unless (isenabled($violation_config->{enabled}) && defined($violation_config->{trigger}));
        foreach my $trigger (split(/\s*,\s*/, $violation_config->{trigger})) {
            my $condition;
            eval {$condition = pf::factory::condition::violation->instantiate($trigger);};
            if ($@) {
                get_logger->error("Invalid trigger $trigger. Error was : $@");
                unless ($self->{invalid_triggers}->{$violation}) {
                    $self->{invalid_trigger}->{$violation} = [];
                }
                push @{$self->{invalid_triggers}->{$violation}}, $trigger;
            }
            else {
                push @conditions, $condition;
            }

            while ($trigger =~ /(accounting::.*?)([,)&]{1}|$)/gi) {
                push @{$self->{accounting_triggers}}, {
                    trigger   => (split('::', $1))[1],
                    violation => $violation
                  };
            }
            if ($trigger =~ /accounting::BandwidthExpired/i) {
                push @{$self->{bandwidth_expired_violations}}, $violation;
            }
        }
        $violation_condition = pf::condition::any->new({conditions => \@conditions});
        push @filters, pf::filter->new({answer => $violation, condition => $violation_condition});
    }
    my $engine = pf::filter_engine->new({ filters => \@filters });
    return $engine;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
