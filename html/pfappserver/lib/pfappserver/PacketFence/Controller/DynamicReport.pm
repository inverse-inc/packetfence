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

__PACKAGE__->config(
    action_args => {
        'search' => { form => 'DynamicReportSearch' },
    }
);

sub index :Path :Args(1) :AdminRole('REPORTS_READ') {
    my ($self, $c, $report_id) = @_;

    $c->stash->{template} = "dynamicreport/index.tt";
    $c->forward("_search", [$report_id]);
}

sub search :Local :AdminRole('REPORTS_READ') {
    my ($self, $c) = @_;

    my $report_id = $c->req->param('report_id');

    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);

    my $search = $form->value;

    $c->stash->{template} = "dynamicreport/search.tt";
    $c->forward("_search", [$report_id, $search]);
}

sub _search :AdminRole('REPORTS_READ') {
    my ($self, $c, $report_id, $form) = @_;
    my $report = $c->stash->{report} = pf::factory::report->new($report_id);

    $form //= {};
    $c->stash->{page_num} = $c->request->param("page_num") // 1;
    my %infos = (
        page => $c->stash->{page_num}, 
        per_page => $form->{"per_page"},
        search => {
            type => $form->{"all_or_any"},
        },
    );

    if($form->{searches}) {
        foreach my $search (@{$form->{searches}}) {
            $infos{search}{conditions} //= [];
            push @{$infos{search}{conditions}}, {field => $search->{name}, operator => $search->{op}, value => $search->{value}}
        }
    }

    $infos{start_date} = $form->{start}->{date} . " " . $form->{start}->{time} if($form->{start});
    $infos{end_date} = $form->{end}->{date} . " " . $form->{end}->{time} if($form->{end});

    my @items = $report->query(%infos);

    $c->stash->{searches} = $report->searches;
    $c->stash->{items} = \@items;
    $c->stash->{page_count} = $report->page_count(%infos);

    if ($c->request->param('export')) {
        $c->stash({
            current_view => 'CSV',
        });
    }
}
1;
