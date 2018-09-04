package pf::AccessScopes;

=head1 NAME

pf::AccessScopes - Access Scope builder

=cut

=head1 DESCRIPTION

Builds the access scopes for a filter file

=cut

use strict;
use warnings;
use pf::log;
use List::MoreUtils qw(uniq);
use pf::factory::condition::access_filter;
use pf::filter;
use pf::filter_engine;
use pf::condition_parser qw(parse_condition_string);

sub new {
    my ($proto) = @_;
    return bless {}, ref($proto) || $proto;
}

sub build {
    my ( $self, $ini ) = @_;
    my %buildData = (
        errors      => undef,
        filter_data => [],
        scopes      => {},
        conditions  => {},
    );
    my $logger = get_logger();
    foreach my $rule ($ini->Sections()) {
        my $data = $self->getSectionData($ini, $rule);
        if ( $rule =~ /^[^:]+:(.*)$/ ) {
            my $condition = $1;
            $logger->info("Building rule '$rule'");
            my ($conditions, $msg) = parse_condition_string($condition);
            unless ( defined $conditions ) {
                $self->_error(\%buildData, $rule, "Error building rule", $msg);
                next;
            }
            $data->{_rule} = $rule;
            push @{ $buildData{filter_data} }, [$conditions, $data];
        }
        else {
            $logger->info("Building condition '$rule'");
            my $condition = eval { 
                pf::factory::condition::access_filter->instantiate($data)
            };
            unless (defined $condition) {
                $self->_error(
                    \%buildData,
                    $rule,
                    "Error building condition",
                    $@
                );
                next;
            }

            $buildData{conditions}{$rule} = $condition;
        }
    }

    foreach my $filter_data ( @{ $buildData{filter_data} } ) {
        $self->build_filter( \%buildData, @$filter_data );
    }

    my %AccessScopes;
    while ( my ( $scope, $filters ) = each %{ $buildData{scopes} } ) {
        $AccessScopes{$scope} =
          pf::filter_engine->new( { filters => $filters } );
    }

    return ( $buildData{errors}, \%AccessScopes );
}

=head2 getSectionData

getSectionData

=cut

sub getSectionData {
    my ($self, $ini, $section) = @_;
    my %data;
    my $default = $ini->{'default'} if exists $ini->{default};
    my @default_params = $ini->Parameters($default) if defined $default;
    for my $param (uniq $ini->Parameters($section), @default_params) {
        my $val = $ini->val($section, $param);
        $val =~ s/\s+$//;
        $data{$param} = $val;
    }
    return \%data;
}

=head2 _error

Record and display an error that occured while building the engine

=cut

sub _error {
    my ($self, $build_data, $rule, $msg, $add_info) = @_;
    my $long_msg = $msg. (defined($add_info) ? " : $add_info" : '');
    $long_msg .= "\n" unless $long_msg =~ /\n\z/s;
    get_logger->error($long_msg);
    push @{$build_data->{errors}}, {rule => $rule, message => $long_msg};
}

sub build_filter {
    my ($self, $build_data, $parsed_conditions, $data) = @_;
    my $condition = eval { $self->build_filter_condition($build_data, $parsed_conditions) };
    if ($condition) {
        push @{$build_data->{scopes}{$data->{scope}}}, pf::filter->new({
            answer    => $data,
            condition => $condition,
        });
    } else {
        $self->_error($build_data, $data->{_rule}, "Error building rule", $@)
    }
}

sub build_filter_condition {
    my ($self, $build_data, $parsed_condition) = @_;
    if (ref $parsed_condition) {
        local $_;
        my ($type, @parsed_conditions) = @$parsed_condition;
        my $conditions = [map {$self->build_filter_condition($build_data, $_)} @parsed_conditions];
        if($type eq 'NOT' ) {
            return pf::condition::not->new({condition => $conditions->[0]});
        }
        my $module = $type eq 'AND' ? 'pf::condition::all' : 'pf::condition::any';
        return $module->new({conditions => $conditions});
    }
    my $condition = $build_data->{conditions}{$parsed_condition};
    return $condition if defined $condition;
    die "condition '$parsed_condition' was not found\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
