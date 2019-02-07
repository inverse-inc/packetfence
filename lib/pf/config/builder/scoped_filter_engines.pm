package pf::config::builder::scoped_filter_engines;

=head1 NAME

pf::config::builder::scoped_filter_engines - Scoped Filter Engines builder

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
use pf::filter_engine;
use pf::condition_parser qw(parse_condition_string);
use base qw(pf::config::builder);

=head2 cleanupBuildData

Merge all conditions and filters to build the scoped filter engines

=cut

sub cleanupBuildData { 
    my ($self, $buildData) = @_;
    foreach my $filter_data ( @{ $buildData->{filter_data} } ) {
        $self->buildFilter( $buildData, @$filter_data );
    }

    while ( my ( $scope, $filters ) = each %{ $buildData->{scopes} } ) {
        $buildData->{entries}{$scope} =
          pf::filter_engine->new( { filters => $filters } );
    }

}

=head2 buildEntry

Preprocess a condition or rule from an entry

=cut

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    if ( $id =~ /^[^:]+:(.*)$/ ) {
        $self->preprocessRule($buildData, $id, $1, $entry);
    } else {
        $self->preprocessCondition($buildData, $id, $entry);
    }

    return undef;
}

=head2 preprocessCondition

Preprocess a condition

=cut

sub preprocessCondition {
    my ($self, $buildData, $id, $entry) = @_;
    my $logger = get_logger();
    $logger->info("Preprocessing filter condition '$id'");
    my $condition = eval {
        pf::factory::condition::access_filter->instantiate($entry)
    };
    unless (defined $condition) {
        $self->_error(
            $buildData,
            $id,
            "Error building condition",
            $@
        );
        return;
    }

    $buildData->{conditions}{$id} = $condition;
    return ;
}

=head2 preprocessRule

Preprocess a rule

=cut

sub preprocessRule {
    my ($self, $buildData, $id, $condition, $entry) = @_;
    my $logger = get_logger();
    $logger->info("Processing rule '$id'");
    my ($conditions, $msg) = parse_condition_string($condition);
    unless ( defined $conditions ) {
        $self->_error($buildData, $id, "Error building rule", $msg);
        return;
    }

    $entry->{_rule} = $id;
    push @{ $buildData->{filter_data} }, [$conditions, $entry];
    return ;
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
    if (!defined $data->{scope}) {
        $self->_error($build_data, $data->{_rule}, "Error building rule", "scope is not defined");
        return;
    }

    my $condition = eval { $self->buildCondition($build_data, $parsed_conditions) };
    if ($condition) {
        push @{$build_data->{scopes}{$data->{scope}}}, pf::filter->new({
            answer    => $data,
            condition => $condition,
        });
    } else {
        $self->_error($build_data, $data->{_rule}, "Error building rule", $@)
    }

}

=head2 buildCondition

build a condition

=cut

sub buildCondition {
    my ($self, $build_data, $parsed_condition) = @_;
    if (ref $parsed_condition) {
        local $_;
        my ($type, @parsed_conditions) = @$parsed_condition;
        my @conditions = map {$self->buildCondition($build_data, $_)} @parsed_conditions;
        if($type eq 'NOT' ) {
            return pf::condition::not->new({condition => $conditions[0]});
        }

        if (@conditions == 1) {
            return $conditions[0];
        }

        my $module = $type eq 'AND' ? 'pf::condition::all' : 'pf::condition::any';
        return $module->new({conditions => \@conditions});
    }

    my $condition = $build_data->{conditions}{$parsed_condition};
    return $condition if defined $condition;
    die "condition '$parsed_condition' was not found\n";
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
