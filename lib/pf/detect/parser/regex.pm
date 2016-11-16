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
use pf::api;
use pf::api::queue;
use pf::api::local;
use pf::util qw(isenabled);
use Clone qw(clone);
use Moo;
extends qw(pf::detect::parser);

has rules => (is => 'rw', default => sub {[]});

sub parse {
    my ($self, $line) = @_;
    my $actions = $self->makeActions($line);
    return undef if @$actions == 0;
    $self->sendActions($actions);
    return 0;
}

sub makeActions {
    my ($self, $line) = @_;
    my @actions;
    foreach my $rule (@{$self->rules}) {
        my $data = $self->parseLineFromRule($rule, $line);
        next unless defined $data;
        foreach my $action (@{$rule->{actions} // []}) {
            push @actions, $self->prepAction($rule, $data, $action);
        }
        last if isenabled($rule->{last_if_match});
    }
    return \@actions;
}

sub parseLineFromRule {
    my ($self, $rule, $line) = @_;
    return undef unless $line =~ $rule->{regex};
    my %data = %+;
    return \%data;
}

sub sendActions {
    my ($self, $actions) = @_;
    my $client = $self->getApiClient();
    foreach my $action (@$actions) {
        $client->notify($action->[0], @{$action->[1]});
    }
}

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

sub getApiClient {
    my ($self) = @_;
    return pf::api::jsonrpcclient->new();
}

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

sub dryRun {
    my ($self, @lines) = @_;
    my @runs;
    for my $line (@lines) {
        my @actions;
        my @rules;
        my @matches;
        my %run = (
            line => $line,
            actions => \@actions,
            rules => \@rules,
            matches => \@matches,
        );
        foreach my $r (@{$self->rules}) {
            my $rule = clone($r);
            my $data = $self->parseLineFromRule($rule, $line);
            next unless defined $data;
            my %match = (
                rule => $rule,
                actions => [],
            );
            push @matches, \%match;
            foreach my $action (@{$rule->{actions} // []}) {
                my $a = $self->prepAction($rule, $data, $action);
                push @actions, $a;
                push @{$match{actions}}, $a;
            }
            push @rules, $rule;
            last if isenabled($rule->{last_if_match});
        }
        push @runs, \%run;
    }
    return \@runs;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

