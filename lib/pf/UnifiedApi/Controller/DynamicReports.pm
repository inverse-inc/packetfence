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
use pf::UnifiedApi::OpenAPI::Generator::DynamicReports;

has 'openapi_generator_class' => 'pf::UnifiedApi::OpenAPI::Generator::DynamicReports';

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
    
    my $id = $self->id;
    my $report = pf::factory::report->new($id);
    if (!defined $report) {
        return $self->render_error(
            500, "Failed creating report ($id). Check server-side logs for details."
        );
    }

    ($status, my $error_or_options) = $report->build_query_options($json);

    if (is_error($status)) {
        return $self->render( json => $error_or_options, status => $status );
    }

    my %info = %$error_or_options;
    my $prevCursor = $info{cursor};
    ($status, my $data) = $report->query(%info);
    if (is_error($status)) {
        return $self->render_error($status, "Failed executing search on report ($id). Check server-side logs for details.");
    }

    my $nextCursor = $report->nextCursor($data, %info);
    $data = $report->format_items($data);
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
    my $id = $self->id;
    my $report = pf::factory::report->new($id);
    if (!defined $report) {
        return $self->render_error(
            500, "Failed executing search on report ($id). Check server-side logs for details."
        );
    }

    $self->render(json => {report_meta => $report->meta_for_options}, status => 200);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
