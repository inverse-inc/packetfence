package pf::config::builder::filter_engine;

=head1 NAME

pf::config::builder::filter_engine - Scoped Filter Engines builder

=cut

=head1 DESCRIPTION

Builds scoped filter engines from a pf::IniFiles

=cut

use strict;
use warnings;
use pf::log;
use List::MoreUtils qw(uniq);
use pf::factory::condition::access_filter;
use pf::filter;
use pf::util qw(expand_ordered_array isdisabled);
use pf::action_spec;
use pf::factory::condition;
use pf::filter_engine;
use pf::condition_parser qw(parse_condition_string);
use base qw(pf::config::builder);

my $logger = get_logger();
=head2 cleanupBuildData

Merge all conditions and filters to build the scoped filter engines

=cut

sub cleanupBuildData { 
    my ($self, $buildData) = @_;
    while ( my ( $scope, $filters ) = each %{ $buildData->{scopes} } ) {
        $buildData->{entries}{$scope} =
          pf::filter_engine->new( { filters => $filters } );
    }
}

=head2 buildEntry

Preprocess a rule

=cut

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    if (isdisabled($entry->{status})) {
        $logger->debug("Skipping Loading rule $id");
        return;
    }

    $logger->info("Processing rule '$id'");
    my ($conditions, $err) = parse_condition_string($entry->{condition});
    unless ( defined $conditions ) {
        $self->_error($buildData, $id, "Error building rule", $err->{highlighted_error});
        return;
    }
    my $scopes = $entry->{scopes};
    unless (defined $scopes) {
        $self->_error($buildData, $id, "Error building rule", "no scopes defined");
        return;
    }
    $entry->{scopes} = $scopes = [split(/\s*,\s*/, $scopes)];
    $entry->{_rule} = $id;
    expand_ordered_array($entry, 'actions', 'action');
    expand_ordered_array($entry, 'answers', 'answer');
    expand_ordered_array($entry, 'params', 'param');
    $entry->{actions} = $self->updateActions($buildData, $id, $entry, $entry->{actions});
    $entry->{answers} = $self->updateAnswers($buildData, $id, $entry, $entry->{answers});
    $entry->{params} = $self->updateParams($buildData, $id, $entry, $entry->{params});
    $self->buildFilter($buildData, $conditions, $entry);
    return undef;
}

sub updateParams {
    my ($self, $buildData, $id, $entry, $params) = @_;
    return $params;
}

sub updateAnswers {
    my ($self, $buildData, $id, $entry, $answers) = @_;
    return $answers;
}

sub updateActions {
    my ($self, $buildData, $id, $entry, $actions) = @_;
    return [
        map {
            my ( $err, $spec ) = pf::action_spec::parse_action_spec($_);
            $err ? () : ($spec)
        } @{$actions}
    ];
}

=head2 _error

Record and log an error

=cut

sub _error {
    my ($self, $build_data, $rule, $msg, $add_info) = @_;
    my $long_msg = $msg. (defined($add_info) ? " : $add_info" : '');
    $long_msg .= "\n" unless $long_msg =~ /\n\z/s;
    get_logger->error($long_msg);
    push @{$build_data->{errors}}, {rule => $rule, message => $long_msg};
}

=head2 buildFilter

build a filter

=cut

sub buildFilter {
    my ($self, $build_data, $parsed_conditions, $data) = @_;
    my $condition = eval { pf::factory::condition::buildCondition($parsed_conditions) };
    if ($@) {
        $self->_error($build_data, $data->{_rule}, "Error building rule", $@);
        return;
    }

    for my $scope (@{$data->{scopes}}) {
        push @{$build_data->{scopes}{$scope}}, pf::filter->new({
            answer    => $data,
            condition => $condition,
        });
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
