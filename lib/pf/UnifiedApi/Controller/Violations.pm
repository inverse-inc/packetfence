package pf::UnifiedApi::Controller::Violations;

=head1 NAME

pf::UnifiedApi::Controller::Violations -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Violations

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::violation;

has dal => 'pf::dal::violation';
has id_key => 'id';
has resource_id => 'id';

sub create {
    my ($self) = @_;
    my $data = $self->parse_json;
    if(pf::violation::violation_exist_open($data->{mac}, $data->{vid})) {
        return $self->render(status => 409, json => { status => 409, message => $self->status_to_error_msg(409) });
    }
    my $response = pf::violation::violation_add($data->{mac}, $data->{vid}, (
        status       => $data->{status},
        start_date   => $data->{start_date},
        release_date => $data->{release_date},
        notes        => $data->{notes},
        ticket_ref   => $data->{ticket_ref}
    ));
    $data->{id} = $response;
    return $self->render(status => 201, json => { data => $data, message => "violation created" }) if $data->{id};
    return $self->render(status => 400, json => { message => $self->status_to_error_msg(400) });
}

#sub read_list {
#    my ($self) = @_;
#    my @violations = pf::violation::violation_view_open_uniq();
#    return $self->render(json => { items => \@violations } ) if scalar @violations > 0 and defined($violations[0]);
#    return $self->render(json => { items => [] });
#}

sub read_list_by_search {
    my ($self) = @_;
    my $search = $self->param('search');
    my @violations = pf::violation::violation_view_desc($search);
    return $self->render(json => { items => \@violations }) if scalar @violations > 0 and defined($violations[0]);
    return $self->render(json => { items => [] });
}

sub read_row_by_id {
    my ($self) = @_;
    my $id = $self->param('id');
    my @violation = pf::violation::violation_view($id);
    return $self->render(json => $violation[0] ) if scalar @violation > 0 and defined($violation[0]);
    return $self->render(status => 404, json => { message => $self->status_to_error_msg(404) });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
