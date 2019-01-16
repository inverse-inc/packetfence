package pf::config::builder::wmi_action;

=head1 NAME

pf::config::builder::wmi_action -

=head1 DESCRIPTION

pf::config::builder::wmi_action

=cut

use strict;
use warnings;
use pf::log;
use pf::condition_parser qw(parse_condition_string);
use pf::factory::ast;
use pf::condition::ast;
use pf::factory::condition::access_filter;
use pf::filter;
use pf::IniFiles;
use base qw(pf::config::builder);

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    if ( $id =~ /^[^:]+:(.*)$/ ) {
        $self->preprocessRule($buildData, $id, $1, $entry);
    } else {
        $self->preprocessCondition($buildData, $id, $entry);
    }

    return undef;
}

sub preprocessCondition {
    my ($self, $buildData, $id, $entry) = @_;
    $entry->{filter} = $entry->{attribute};
    my $condition = eval {
        $entry->{operator} eq 'advance'
          ? pf::condition::ast->new(ast => pf::factory::ast::build($entry->{value}))
          : pf::factory::condition::access_filter->instantiate($entry);
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
    return;
}

sub preprocessRule {
    my ($self, $buildData, $id, $condition, $entry) = @_;
    my ($conditions, $msg) = parse_condition_string($condition);
    unless ( defined $conditions ) {
        $self->_error($buildData, $id, "Error building rule", $msg);
        return;
    }
    $entry->{_rule} = $id;
    push @{ $buildData->{filter_data} }, [$conditions, $entry];
}

sub cleanupBuildData {
    my ($self, $buildData) = @_;
    foreach my $filter_data ( @{ $buildData->{filter_data} } ) {
        $self->buildFilter( $buildData, @$filter_data );
    }

}

sub buildFilter {
    my ($self, $build_data, $parsed_conditions, $data) = @_;
    my $condition = eval { $self->buildCondition($build_data, $parsed_conditions) };
    if ($condition) {
        push @{$build_data->{filters}}, pf::filter->new({
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

=head2 _error

Record and log an error

=cut

sub _error {
    my ($self, $build_data, $rule, $msg, $add_info) = @_;
    my $long_msg = $msg. (defined($add_info) ? " : $add_info" : '');
    $long_msg .= "\n" unless $long_msg =~ /\n\z/s;
    get_logger->error($long_msg);
    push @{$build_data->{errors}}, {rule => $rule, message => $long_msg};
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

