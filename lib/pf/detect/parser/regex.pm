package pf::detect::parser::regex;

=head1 NAME

pf::detect::parser::regex -

=cut

=head1 DESCRIPTION

pf::detect::parser::regex

=cut

use strict;
use warnings;
use pf::log;
use pf::api::queue;
use pf::util qw(isenabled clean_mac);
use Clone qw(clone);
use Moo;
use pf::ip4log;
extends qw(pf::detect::parser);

has rules => (is => 'rw', default => sub {[]});

=head2 parse

Parse and send the actions defined

=cut

sub parse {
    my ($self, $line) = @_;
    my $matches = $self->matchLine($line);
    return undef if @$matches == 0;
    my $logger = get_logger();
    my $id = $self->id;
    foreach my $match (@$matches) {
        $logger->trace( sub {"Parser id $id : Sending matched actions for $match->{rule}->{name}"} );
        $self->sendActions($match->{actions});
    }
    return 0;
}

=head2 parseLineFromRule

parse the Line using the rule

=cut

sub parseLineFromRule {
    my ($self, $rule, $line) = @_;
    return undef unless $line =~ $rule->{regex};
    my %data = %+;
    if (exists $data{mac}) {
        $data{mac} = clean_mac($data{mac});
    }
    if (isenabled($rule->{ip_mac_translation}) ) {
        if (exists $data{ip} && !exists $data{mac}) {
            my $mac = pf::ip4log::ip2mac($data{ip});
            if ($mac) {
                $data{mac} = $mac;
            }
        }
        elsif (exists $data{mac} && !exists $data{ip}) {
            my $ip = pf::ip4log::mac2ip($data{mac});
            if ($ip) {
                $data{ip} = $ip;
            }
        }
    }
    return \%data;
}

=head2 sendActions

send actions using an api client

=cut

sub sendActions {
    my ($self, $actions) = @_;
    my $client = $self->getApiClient();
    foreach my $action (@$actions) {
        $client->notify($action->[0], @{$action->[1]});
    }
}

=head2 prepAction

prepare an action from an action spec

=cut

sub prepAction {
    my ($self, $rule, $data, $action_spec) = @_;
    my $logger = get_logger;
    unless ($action_spec =~ /^\s*([^:]+)\s*:\s*(.*)\s*$/) {
        $logger->error("Invalid action spec provided");
        return;
    }
    my $action        = $1;
    my $action_params = $2;
    $logger->info(
        sub {
            my $id = $self->id;
            "Parser id $id : Matched rule '$rule->{name}' : preparing action spec '$action_spec'";
        });
    my $params = $self->evalParams($action_params, $data);
    return [$action, $params];
}

=head2 getApiClient

get the api client

=cut

sub getApiClient {
    my ($self) = @_;
    return pf::api::queue->new(queue => 'pfdetect');
}

=head2 evalParams

eval parameters

=cut

sub evalParams {
    my ($self, $action_params, $args) = @_;
    my @params = split(/\s*,\s*/, $action_params);
    my @return;
    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        my @param_unit = split(/\s*=\s*/, $param);
        push @return, @param_unit;
    }
    return \@return;
}


=head2 matchLine

match line

=cut

sub matchLine {
    my ($self, $line) = @_;
    my @actions;
    my @rules;
    my @matches;
    my $logger = get_logger();
    my $id = $self->id;
    $logger->trace( sub { "Pfdetect Regex $id Attempting to match line : $line" });
    foreach my $r (@{$self->rules}) {
        my $rule_name = $r->{name};
        $logger->trace( sub { "Pfdetect Regex $id checking rule $rule_name" });
        my $rule = clone($r);
        my $data = $self->parseLineFromRule($rule, $line);
        next unless defined $data;
        $logger->trace( sub { "Pfdetect Regex $id rule $rule_name matched" });
        my %match = (
            rule => $rule,
            actions => [],
        );
        push @matches, \%match;
        foreach my $action (@{$rule->{actions} // []}) {
            $logger->trace( sub { "Pfdetect Regex $id rule $rule_name applying action $action" });
            my $a = $self->prepAction($rule, $data, $action);
            push @{$match{actions}}, $a;
        }
        push @rules, $rule;
        if (isenabled($rule->{last_if_match})) {
            $logger->trace(sub {"Pfdetect Regex $id rule $rule_name last match"});
            last;
        }
    }
    return \@matches;
}

=head2 dryRun

Return dry run

=cut

sub dryRun {
    my ($self, @lines) = @_;
    my @runs;
    for my $line (@lines) {
        my %run = (
            line => $line,
            matches => $self->matchLine($line),
        );
        push @runs, \%run;
    }
    return \@runs;
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

