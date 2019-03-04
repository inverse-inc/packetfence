package pf::filter_engine;

=head1 NAME

pf::filter_engine The pf filtering engine

=cut

=head1 DESCRIPTION

pf::filter_engine

=cut

use strict;
use warnings;
use Moose;
use List::Util qw(first);

=head1 ATTRIBUTES

=head2 filters

The filters attribute

=cut

has filters => (
    traits  => ['Array'],
    isa     => 'ArrayRef[pf::filter]',
    default => sub {[]},
    handles => {
        all_filters        => 'elements',
        add_filter         => 'push',
        match_filters      => 'grep',
        count_filters      => 'count',
        has_filters        => 'count',
        no_filters         => 'is_empty',
    },
);

=head1 METHODS

=head2 match_first

Matches the first filter an returns the answer

=cut

sub match_first {
    my ($self, @args) = @_;
    my $arg = $self->build_match_arg(@args);
    my $filter = first { $_->match($arg) } $self->all_filters;
    return undef unless $filter;
    return $filter->get_answer($arg);
}

=head2 match_all

Matches all the filters and returns all the answers for the filters

=cut

sub match_all {
    my ($self, @args) = @_;
    my $arg = $self->build_match_arg(@args);
    my @filters = grep {$_->match($arg)} $self->all_filters;
    return unless @filters;
    return map {$_->get_answer($arg)} @filters;
}


=head2 build_match_arg

Build the argument for matching

=cut

sub build_match_arg {
    my ($self,@args) = @_;
    return $args[0];
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

