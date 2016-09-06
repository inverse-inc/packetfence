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

    $c->stash->{template} = "dynamicreport/view.tt";
    $c->forward("_search", [$report_id]);
}

sub search :Local :AdminRole('REPORTS') {
    my ($self, $c) = @_;

    my $report_id = $c->req->param('report_id');

    $c->stash->{template} = "dynamicreport/search.tt";
    $c->forward("_search", [$report_id]);
}

sub _search :AdminRole('REPORTS') {
    my ($self, $c, $report_id) = @_;
    my $report = $c->stash->{report} = pf::factory::report->new($report_id);

    $c->stash->{page_num} = $c->request->param("page_num") // 1;
    my %infos = (
        page => $c->stash->{page_num}, 
        per_page => $c->request->param("per_page"),
    );
    my @items = $report->query(%infos);

    $c->stash->{items} = \@items;
    $c->stash->{page_count} = $report->page_count(%infos);
}
1;
