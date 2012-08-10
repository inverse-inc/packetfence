package pfappserver::Controller::Graph;

=head1 NAME

pfappserver::Controller::Graph - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=head2 auto

Allow only authenticated users

=cut
sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->req->referer);
        $c->detach();
    }
}

=head2 begin

Set the default view to pfappserver::View::JSON.

=cut
sub begin :Private {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';
}

=head2 _graphLine

=cut
sub _graphLine :Private {
    my ( $self, $c, $title, $interval ) = @_;

    $interval = 'day' unless ($interval);
    my $id = $title . 'Per' . ucfirst $interval;
    $id =~ s/ //g;
    my ($status, $result) = $c->model('Graph')->timeBase($c->action->name, $interval);
    if (is_success($status)) {
        $c->stash->{title} = $title;
        $c->stash->{id} = $id;
        $c->stash->{graphtype} = 'line';
        $c->stash->{interval} = $interval;
        $c->stash->{size} = 'large';
        $c->stash->{labels} = $result->{labels};
        $c->stash->{series} = $result->{series};
        $c->stash->{template} = 'graph/line.tt';
        $c->stash->{current_view} = 'HTML';
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }
}

=head2 _graphPie

=cut
sub _graphPie :Private {
    my ( $self, $c, $title, $options ) = @_;

    my $id = $title . ucfirst $options->{report};
    $id =~ s/ //g;
    my ($status, $result) = $c->model('Graph')->ratioBase($c->action->name, $options);

    if (is_success($status)) {
        $c->stash->{title} = $title;
        $c->stash->{label} = $options->{fields}->{label};
        $c->stash->{value} = $options->{fields}->{value} || $options->{fields}->{count};
        $c->stash->{report} = $options->{report};
        $c->stash->{reports} = $options->{reports};
        $c->stash->{option} = $options->{option};
        $c->stash->{options} = $options->{options};

        $c->stash->{id} = $id;
        $c->stash->{graphtype} = 'pie';
        $c->stash->{size} = 'large';
        $c->stash->{labels} = $result->{labels};
        $c->stash->{series} = $result->{series};
        $c->stash->{values} = $result->{values};
        $c->stash->{piecut} = $result->{piecut};

        $c->stash->{template} = 'graph/pie.tt';
        $c->stash->{current_view} = 'HTML';
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }
}

=head2 nodes

=cut
sub nodes :Local {
    my ( $self, $c, $interval ) = @_;

    $self->_graphLine($c, 'Nodes', $interval);
}

=head2 violations

=cut
sub violations :Local {
    my ( $self, $c, $interval ) = @_;

    $self->_graphLine($c, 'Violations', $interval);
}

=head2 os

=cut
sub os :Local {
    my ( $self, $c, $report ) = @_;

    # Validate URL arguments
    $report = 'all' unless ($report && $report =~ m/^(all|active)$/);

    $self->_graphPie($c, 'Operating Systems', 
                     { fields => { label => 'description',
                                   count => 'count' },
                       report => $report,
                       reports => ['all', 'active'] }
                    );
}

=head2 connectiontype

=cut
sub connectiontype :Local {
    my ( $self, $c, $report ) = @_;

    # Validate URL arguments
    $report = 'all' unless ($report && $report =~ m/^(all|active)$/);

    $self->_graphPie($c, 'Connections Types',
                     { fields => { label => 'connection_type',
                                   'count' => 'connections' },
                       reports => ['all', 'active'],
                       report => $report }
                    );
}

=head2 connectiontypereg

=cut
sub connectiontypereg :Local {
    my ( $self, $c, $report ) = @_;

    # Validate URL arguments
    $report = 'all' unless ($report && $report =~ m/^(all|active)$/);

    $self->_graphPie($c, 'Connections Types (Registered)', 
                     { fields => { label => 'connection_type',
                                   'count' => 'connections' },
                       reports => ['all', 'active'],
                       report => $report }
                    );
}

=head2 ssid

=cut
sub ssid :Local {
    my ( $self, $c, $report ) = @_;

    # Validate URL arguments
    $report = 'all' unless ($report && $report =~ m/^(all|active)$/);

    $self->_graphPie($c, 'SSID',
                     { fields => { label => 'ssid',
                                   count => 'nodes' },
                       reports => ['all', 'active'],
                       report => $report }
                    );
}

=head2 nodebandwidth

=cut
sub nodebandwidth :Local {
    my ( $self, $c, $report, $option ) = @_;

    # Validate arguments
    $report = 'all'; # we only support this report, see pf::pfcmd::report
    $option = 'accttotal' unless ($option && $option =~ m/^(accttotal|acctinput|acctoutput)$/);

    $self->_graphPie($c, 'Top Bandwidth Consumers',
                     { fields => { label => 'callingstationid',
                                   count => $option."octets",
                                   value => $option },
                       report => $report,
                       options => ['accttotal', 'acctinput', 'acctoutput'],
                       option => $option }
                    );
}

=head2 osclassbandwidth

=cut
sub osclassbandwidth :Local {
    my ( $self, $c, $report, $option ) = @_;

    # Validate arguments
    $report = 'all' unless ($report && $report =~ m/^(all|day|week|month|year)$/);
    $option = 'accttotal'; # we only sypport this field, see pf::pfcmd::report

    $self->_graphPie($c, 'Bandwidth per Operating System Class',
                     { fields => { label => 'dhcp_fingerprint',
                                   count => $option."octets",
                                   value => $option },
                       reports => ['all', ['day', 'current day'], ['week', 'current week'], ['month', 'current month'], ['year', 'current year']],
                       report => $report });
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
