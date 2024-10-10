package fingerbank::SourceMatcher;

=head1 NAME

fingerbank::SourceMatcher

=head1 DESCRIPTION

Class for matching multiple sources

=cut

use Moose;

has 'sources' => (is => 'rw', isa => 'ArrayRef', default => sub {[]});

has 'cache' => (is => 'rw', required => 1);

=head2 register_source

Register source into the engine for use in matching

=cut

sub register_source {
  my ($self, $source) = @_;
  $source->cache($self->cache);
  push @{$self->sources}, $source;
}

=head2 match_best

Match the result with the best score from all the available sources.

=cut

sub match_best {
    my ($self, $args) = @_;
    my $logger = fingerbank::Log::get_logger;
    my ($results, $results_array) = $self->match_all($args);

    unless(@$results_array){
        $logger->debug("No result found for query.");
        return undef;
    }

    my @ordered = reverse sort { $results->{$a} <=> $results->{$b} } keys %$results;
    my $best_match = $results_array->[$ordered[0]];
    my $pretty_args = '[' . join(',', map { "'$_' : '$args->{$_}'" // "(undefined)" } keys %$args) . ']';
    if($best_match){
        $logger->debug("Found '$best_match->{device}->{name}' with score $best_match->{score} for args : $pretty_args");
        return $best_match;
    }
    else {
        $logger->debug("Could not find any match with args : $pretty_args");
        return undef;
    }
}

=head2 match_all

Match all the results from all the available sources

=cut

sub match_all {
    my ($self, $args) = @_;

    my $results = {};
    foreach my $source (@{$self->sources}){
        my ( $status, $result ) = $source->match($args, $results);
        if ( $status eq $fingerbank::Status::OK ){
            $results->{ref($source)} = $result;
        }
    }
    my ($sorted, $results_array) = $self->merge_from_results($results);
    return ($sorted, $results_array);
}

=head2 merge_from_results

Will merge the results from the same hierarchy and add their score together
The device that is the lowest in the hierarchy will be the one with the highest score in that hierarchy as it contains the scores of all it's parents.

=cut

sub merge_from_results {
    my ($self, $results) = @_;
    my $logger = fingerbank::Log::get_logger;
    my $results_per_device = {};
    my $score_per_result = {};
    my @results_array;
    # we sort each result by the resulting device
    foreach my $source_id (keys %$results){
        my $device_id = $results->{$source_id}->{device}->{id};
        $results_per_device->{$device_id} = [] unless defined($results_per_device->{$device_id});
        push @{$results_per_device->{$device_id}}, $results->{$source_id};
    }

    $logger->trace(sub {use Data::Dumper;"Results per device : ".Dumper($results_per_device)});

    while (my ($device, $results) = each %$results_per_device) {
        my $score = 0;
        # adding each result with same hit
        foreach my $result (@$results) {
            $score += $result->{score}
        }
        # cycling through this device parents and adding the scores found
        # from hits on it's parents
        foreach my $parent (@{$results->[0]->{device}->{parents}}){
            my $parent_id = $parent->{id};
            if(exists($results_per_device->{$parent_id})) {
                foreach my $result (@{$results_per_device->{$parent_id}}){
                    $logger->debug("Adding score from parent result ".$result->{score}." $parent_id");
                    $score += $result->{score}
                }
            }
        }
        $score_per_result->{@results_array} = $score;
        $results->[0]->{score} = $score;
        push @results_array, $results->[0];
    }
    $logger->trace(sub {use Data::Dumper;"After merge_from_results: ".Dumper($score_per_result).Dumper(\@results_array)});
    return ($score_per_result, \@results_array);
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
