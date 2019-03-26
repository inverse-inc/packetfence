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
use pf::ConfigStore::Report;

sub configStore {
    return pf::ConfigStore::Report->new;
}

sub list {
    my ($self) = @_;
    $self->render(json => { items => $self->configStore->readAll("id") }, status => 200);
}

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
