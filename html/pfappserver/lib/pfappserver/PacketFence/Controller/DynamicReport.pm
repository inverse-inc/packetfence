package pfappserver::PacketFence::Controller::DynamicReport;

=head1 NAME

pfappserver::PacketFence::Controller::DynamicReport - Catalyst Controller

=head1 DESCRIPTION

Controller for dynamic reports

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::factory::report;

BEGIN {
    extends 'pfappserver::Base::Controller';
}

sub view :Local :Args(1) :AdminRole('REPORTS') {
    my ($self, $c, $report_id) = @_;
    my $report = $c->stash->{report} = pf::factory::report->new($report_id);

    my @items = $report->query;
    $c->stash->{items} = \@items;
    use Data::Dumper;
    $c->log->info(Dumper(\@items));
}

1;
