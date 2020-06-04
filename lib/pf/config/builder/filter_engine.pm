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
    $entry->{actions} = [
        map {
            my ( $err, $spec ) = pf::action_spec::parse_action_spec($_);
            $err ? () : ($spec)
        } @{ $entry->{actions} }
    ];
    $self->buildFilter($buildData, $conditions, $entry);
    return undef;
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
    my $condition = eval { $self->buildCondition($build_data, $parsed_conditions) };
    if ($condition) {
        for my $scope (@{$data->{scopes}}) {
            push @{$build_data->{scopes}{$scope}}, pf::filter->new({
                answer    => $data,
                condition => $condition,
            });
        }
    } else {
        $self->_error($build_data, $data->{_rule}, "Error building rule", $@)
    }

}

our %LOGICAL_OPS = (
    AND => 'pf::condition::all',
    OR  => 'pf::condition::any'
);

our %BINARY_OP = (
    "==" => 'pf::condition::equals',
    "!=" => 'pf::condition::not_equals',
    "=~" => 'pf::condition::regex',
    "!~" => 'pf::condition::regex_not',
    ">"  => 'pf::condition::greater',
    ">=" => 'pf::condition::greater_equals',
    "<"  => 'pf::condition::lower',
    "<=" => 'pf::condition::lower_equals',
);

our %FUNC_OPS = (
    'includes'               => 'pf::condition::includes',
    'contains'               => 'pf::condition::matches',
    'not_contains'           => 'pf::condition::not_matches',
    'defined'                => 'pf::condition::is_defined',
    'not_defined'            => 'pf::condition::not_defined',
    'date_is_before'         => 'pf::condition::date_before',
    'date_is_after'          => 'pf::condition::date_after',
    'fingerbank_device_is_a' => 'pf::condition::fingerbank::device_is_a',
    'starts_with'            => 'pf::condition::starts_with',
    'ends_with'              => 'pf::condition::ends_with',
    'time_period' =>            'pf::condition::time_period',
);

=head2 buildCondition

build a condition

=cut

sub buildCondition {
    my ($self, $build_data, $ast) = @_;
    if (ref $ast) {
        local $_;
        my ($op, @rest) = @$ast;
        if ($op eq 'NOT' ) {
            return pf::condition::not->new(
                {
                    condition => $self->buildCondition( $build_data, @rest)
                }
            );
        }

        if (exists $LOGICAL_OPS{$op}) {
            if (@rest == 1) {
                return $self->buildCondition( $build_data, @rest);
            }

            return $LOGICAL_OPS{$op}->new({conditions => [map { $self->buildCondition($build_data, $_) } @rest]});
        }

        if (exists $BINARY_OP{$op}) {
            my ($key, $val) = @rest;
            my $sub_condition = $BINARY_OP{$op}->new(value => $val);
            return build_parent_condition($sub_condition, $key);
        }

        if ($op eq 'FUNC') {
            my ($func, $params) = @rest;
            my $wrap_in_not;
            if (!exists $FUNC_OPS{$func}) {
                die "op '$func' not handled" unless ($func =~ s/^not_//);
                die "op 'not_$func' not handled" unless exists $FUNC_OPS{$func};
                $wrap_in_not = 1;
            }

            my ($key, $val) = @$params;
            my $sub_condition = $FUNC_OPS{$func}->new(value => $val);
            my $condition = build_parent_condition($sub_condition, $key);
            return $wrap_in_not ? pf::condition::not->new({condition => $condition}) : $condition;
        }

        die "op '$op' not handled";
    }

    die "condition '$ast' not defined\n";
}

sub build_parent_condition {
    my ($child, $key) = @_;
    my @parents = split /\./, $key;
    if (@parents == 1) {
        return pf::condition::key->new({
            key       => $key,
            condition => $child,
        });
    }

    return _build_parent_condition($child, @parents);
}

sub _build_parent_condition {
    my ($child, $key, @parents) = @_;
    if (@parents == 0) {
        return pf::condition::key->new({
            key       => $key,
            condition => $child,
        });
    }

    return pf::condition::key->new({
        key       => $key,
        condition => _build_parent_condition($child, @parents),
    });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
