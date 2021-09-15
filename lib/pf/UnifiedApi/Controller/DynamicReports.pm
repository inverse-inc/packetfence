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
    if (is_error($status)) {
        return $self->render_error(400, "Unable to parse JSON query");
    }

    my $prevCursor = $json->{cursor};
    my $cursor = ($prevCursor // 0) + 0;
    my $report = pf::factory::report->new($self->id);
    my $query  = $json->{query};
    my $where = defined $query ? pf::UnifiedApi::Search::searchQueryToSqlAbstract($json->{query}) : undef;
    my $limit = $json->{limit} // 25;
    my $page = $cursor / $limit ;

    my %info = (
        page => ($page + 1),
        sql_abstract_search => $where,
        per_page => $limit + 1,
        order => $json->{sort},
        start_date => $json->{start_date},
        end_date => $json->{end_date},
        limit => $limit,
        cursor => $cursor,
    );

    ($status, my $data) = $report->query(%info);

    if (is_error($status)) {
        return $self->render_error($status, "Failed executing search on report. Check server-side logs for details.");
    }

    my $nextCursor = $report->nextCursor($data, %info);

    return $self->render(
        json   => { 
            items => $data,
            nextCursor => $nextCursor,
            prevCursor => $prevCursor,
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
    my $report_id = $self->id;
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

sub id {
    my ($self) = @_;
    return $self->escape_url_param($self->stash('report_id'));
}

=head2 resource

Get a dynamic report

=cut

sub get {
    my ($self) = @_;
    $self->render(json => {item => $self->stash('report')}, status => 200);
}

=head2 options

options

=cut

sub options {
    my ($self) = @_;
    $self->render(json => {report_meta => $self->build_report_meta}, status => 200);
}

=head2 build_report_meta

build_report_meta

=cut

sub build_report_meta {
    my ($self) = @_;
    my $report = pf::factory::report->new($self->id);
    return {
        query_fields => $self->build_query_fields($report),
        columns => $self->build_columns($report),
        has_cursor   => $self->hasCursor($report),
        has_date_range   => $self->hasDateRange($report),
        (
            map { ($_ => $report->{$_}) } qw(description)
        ),
    };
}

sub hasCursor {
    my ($self) = @_;
    return $self->json_true;
}

sub hasDateRange {
    my ($self, $item) = @_;
    if (exists $item->{date_field} && length($item->{date_field}) > 0) {
        return $self->json_true;
    }

    return $self->json_false;
}

=head2 build_query_fields

build_query_fields

=cut

sub build_query_fields {
    my ($self, $item) = @_;
    return [
        map_searches($item->{searches} // [])
    ];
}

sub map_searches {
    my ($searches) = @_;
    return map { { type => $_->{type}, text => $_->{display}, name => $_->{field} }  } @$searches;
}

sub build_columns {
    my ($self, $report) = @_;
    return [ map { $self->format_column($report, $_) } @{ $report->{columns} } ];
}

sub format_column {
    my ($self, $report, $c) = @_;
    my $l = $c;
    $l =~ s/^[\S]+\s+//;
    $l =~ s/as\s+//i;
    $l =~ s/\s*$//;
    $l =~ s/\s*$//;
    $l =~ s/^["']([^"']+)["']$/$1/;
    return {
        text => $l,
        name => $l,
        is_person => ( $report->is_person_field($l) ? $self->json_true : $self->json_false ),
        is_node   => ( $report->is_node_field($l) ? $self->json_true : $self->json_false ),
    };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
