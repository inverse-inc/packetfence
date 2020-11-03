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

    if ($entry->{status} && isdisabled($entry->{status})) {
        $logger->debug("Skipping disabled rule $id");
        print "skip $id is disabled\n";
        return;
    }
    if (!$entry->{advanced_filter}) {
        $logger->debug("Skipping empty rule $id");
        print "skip $id filter is empty\n";
        return;
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

1;

