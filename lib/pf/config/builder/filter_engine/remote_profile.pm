package pf::config::builder::filter_engine::remote_profile;

=head1 NAME

pf::config::builder::filter_engine::remote_profile -

=head1 DESCRIPTION

pf::config::builder::filter_engine::remote_profile

=cut

use strict;
use warnings;
use base qw(pf::config::builder::filter_engine);
use pf::mini_template;
use pf::log;
use pf::util qw(isdisabled);
use pf::condition_parser qw(parse_condition_string);

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;

    my $logger = get_logger();

    if ($id ne "default" && $entry->{status} && isdisabled($entry->{status})) {
        $logger->debug("Skipping disabled rule $id");
        return;
    }

    if ($id eq "default") {
        $entry->{advanced_filter} = "true()";
    }

    if (!$entry->{advanced_filter}) {
        $entry->{advanced_filter} = $entry->{basic_filter_type} . "==" . '"' . $entry->{basic_filter_value} . '"';
    }

    $logger->info("Processing rule '$id'");
    my ($conditions, $err) = parse_condition_string($entry->{advanced_filter});
    unless ( defined $conditions ) {
        $self->_error($buildData, $id, "Error building rule", $err->{highlighted_error});
        return;
    }
    $entry->{scopes} = ['instantiate'];
    $entry->{_rule} = $id;
    $self->buildFilter($buildData, $conditions, $entry);
    return undef;
}

sub cleanupBuildData {
    my ($self, $buildData) = @_;

    # reorder the filters so that default is last since its a catchall
    my @instantiate_filters = @{$buildData->{scopes}{'instantiate'}};
    my @reordered = @instantiate_filters[1 .. $#instantiate_filters];
    push @reordered, $instantiate_filters[0];
    $buildData->{scopes}{'instantiate'} = \@reordered;
    
    $self->SUPER::cleanupBuildData($buildData);
}

1;

