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
use pf::util qw(isenabled clean_mac);
use Clone qw(clone);
use Moo;
use pf::ip4log;

has id => (is => 'rw', required => 1);

has path => (is => 'rw', required => 1);

has type => (is => 'rw', required => 1);
 
has status => (is => 'rw', default =>  sub { "enabled" });

has rules => (is => 'rw', default => sub {[]});

=head2 parseLineFromRule

parse the Line using the rule

=cut

sub parseLineFromRule {
    my ($self, $rule, $line) = @_;
    use re::engine::RE2 -strict => 1;
    return 0, undef unless $line =~ $rule->{regex};
    my %data = %+;
    my $success = 1;
    if (exists $data{mac}) {
        $data{mac} = clean_mac($data{mac});
    }
    return $success, \%data;
}

=head2 ipMacTranslation

ipMacTranslation

=cut

sub ipMacTranslation {
    my ($self, $rule, $data) = @_;
    my $success = 1;
    if (isenabled($rule->{ip_mac_translation}) ) {
        if (exists $data->{ip} && !exists $data->{mac}) {
            my $mac = pf::ip4log::ip2mac($data->{ip});
            if ($mac) {
                $data->{mac} = $mac;
            }
            else {
                my $logger = get_logger();
                $logger->error("Parser id " . $self->id . " : Failed performing ip2mac translation skipping rule $rule->{name}");
                $success = 0;
            }
        }
        elsif (exists $data->{mac} && !exists $data->{ip}) {
            my $ip = pf::ip4log::mac2ip($data->{mac});
            if ($ip) {
                $data->{ip} = $ip;
            }
            else {
                my $logger = get_logger();
                $logger->error("Parser id " . $self->id . " : Failed performing mac2ip translation skipping rule $rule->{name}");
                $success = 0;
            }
        }
    }
    return $success;
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
    return { api_method => $action, api_parameters => $params};
}

=head2 evalParams

eval parameters

=cut

sub evalParams {
    my ($self, $action_params, $args) = @_;
    my @params = split(/\s*[,=]\s*/, $action_params);
    my @return;
    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        push @return, $param;
    }
    return \@return;
}


=head2 matchLine

match line

=cut

sub matchLine {
    my ($self, $line, $include_ip2mac_failures) = @_;
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
        my ($success, $data) = $self->parseLineFromRule($rule, $line);
        if ($success == 0) {
            next;
        }
        $logger->trace( sub { "Pfdetect Regex $id rule $rule_name matched" });
        $success = $self->ipMacTranslation($r, $data);
        if ($success == 0 && !$include_ip2mac_failures) {
            $logger->error("Pfdetect Regex $id rule $rule_name error with ip <=> mac translations");
            next;
        }
        my %match = (
            rule => $rule,
            actions => [],
            success => $success,
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
            matches => $self->matchLine($line, 1),
        );
        push @runs, \%run;
    }
    return \@runs;
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
