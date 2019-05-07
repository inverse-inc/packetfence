package pf::UnifiedApi::Controller::DynamicReports;

=head1 NAME

pf::UnifiedApi::Controller::DynamicReports -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::DynamicReports

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::constants;
use pf::error qw(is_error);
use pf::ConfigStore::Report;
use pf::UnifiedApi::Search;
use pf::Report;
use pf::factory::report;

=head2 configStore

Get the dynamic reports config store

=cut

sub configStore {
    return pf::ConfigStore::Report->new;
}

=head2 search

Execute a search on a specific dynamic report

=cut

sub search {
    my ($self) = @_;
    my ($status, $json) = $self->parse_json;

    if(is_error($status)) {
        return $self->render_error(400, "Unable to parse JSON query");
    }

    my $where = pf::UnifiedApi::Search::searchQueryToSqlAbstract($json->{query});

    my $limit = $json->{limit} // 25;
    my $page = (($json->{cursor} // 0) / $limit);

    my $report = pf::factory::report->new($self->stash('report_id'));
    my %info = (
        page => ($page + 1),
        sql_abstract_search => $where,
        per_page => $limit,
        order => $json->{sort},
        start_date => $json->{start_date},
        end_date => $json->{end_date},
    );

    ($status, my $data) = $report->query(%info);

    if(is_error($status)) {
        return $self->render_error($status, "Failed executing search on report. Check server-side logs for details.");
    }

    my $page_count = $report->page_count(%info);

    return $self->render(
        json   => { 
            items => $data,
            nextCursor => ($page < $page_count ? ($page+1)*$json->{limit} : undef),
            prevCursor => ($page eq 0 ? 0 : ($page-1)*$json->{limit}),
        },
        status => 200,
    );
}

=head2 list

List all the dynamic reports

=cut

sub list {
    my ($self) = @_;
    $self->render(json => { items => $self->configStore->readAll("id") }, status => 200);
}

=head2 resource

Get a dynamic report

=cut

sub resource {
    my ($self) = @_;
    my $report_id = $self->stash('report_id');
    my $cs = $self->configStore;
    if($cs->hasId($report_id)) {
        $self->stash->{report} = $cs->read($report_id, "id");
        return $TRUE;
    }
    else {
        $self->render_error(404, "Report $report_id not found");
        return $FALSE;
    }
}

=head2 resource

Get a dynamic report

=cut

sub get {
    my ($self) = @_;
    $self->render(json => {item => $self->stash('report')}, status => 200);
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
