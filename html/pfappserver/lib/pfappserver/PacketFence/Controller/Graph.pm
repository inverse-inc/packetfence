package pfappserver::PacketFence::Controller::Graph;

=head1 NAME

pfappserver::PacketFence::Controller::Graph - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use DateTime;
use DateTime::Locale;
use HTTP::Status qw(:constants is_error is_success);
use Moose;
use Readonly;
use namespace::autoclean;

BEGIN { extends 'pfappserver::Base::Controller'; }

Readonly::Scalar our $DASHBOARD => 'dashboard';
Readonly::Scalar our $REPORTS => 'reports';

Readonly::Scalar our $GRAPH_REGISTERED_NODES => 'Registered Nodes';
Readonly::Scalar our $GRAPH_UNREGISTERED_NODES => 'Unregistered Nodes';
Readonly::Scalar our $GRAPH_NEW_NODES => 'New Nodes';
Readonly::Scalar our $GRAPH_VIOLATIONS => 'Violations';
Readonly::Scalar our $GRAPH_WIRED_CONNECTIONS => 'Wired Connections';
Readonly::Scalar our $GRAPH_WIRELESS_CONNECTIONS => 'Wireless Connections';
Readonly::Array our @GRAPHS =>
  (
   $GRAPH_REGISTERED_NODES,
   $GRAPH_UNREGISTERED_NODES,
   $GRAPH_NEW_NODES,
   $GRAPH_VIOLATIONS,
   $GRAPH_WIRED_CONNECTIONS,
   $GRAPH_WIRELESS_CONNECTIONS
  );

=head1 METHODS

=head2 begin

Set the default view to pfappserver::View::JSON.

=cut

sub begin :Private {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
}

=head2 _saveRange

Save the period range for a specific section.

=cut

sub _saveRange :Private {
    my ($self, $c, $section, $start, $end) = @_;

    if ($start && $end) {
        if (my ($syear, $smonth, $sday) = $start =~ m/(\d{4})-?(\d{1,2})-?(\d{1,2})/) {
            if (my ($eyear, $emonth, $eday) = $end =~ m/(\d{4})-?(\d{1,2})-?(\d{1,2})/) {
                $c->session->{$section}->{start} = sprintf("%i-%02i-%02i", $syear, $smonth, $sday);
                $c->session->{$section}->{end} = sprintf("%i-%02i-%02i", $eyear, $emonth, $eday);
            }
        }
    }
    unless ($c->session->{$section}->{start} && $c->session->{$section}->{end}) {
        # Default to the last 7 days for the dashboard, 30 for the reports
        my $days = ($section eq $DASHBOARD)? 7 : 30;
        $c->session->{$section}->{start} = POSIX::strftime( "%Y-%m-%d", localtime(time() - $days*24*60*60 ) );
        $c->session->{$section}->{end} = POSIX::strftime( "%Y-%m-%d", localtime() );
    }
}

=head2 _range

Retrieve the period range for a specific section from the web session.

=cut

sub _range :Private {
    my ($self, $c, $section) = @_;

    my ($year, $mon, $day, $time, $start, $end);

    ($year, $mon, $day) = split( /\-/, $c->session->{$section}->{start});
    $time = DateTime->new(year => $year, month => $mon, day => $day);
    $time->set_locale($c->language);
    $start = $time->format_cldr($time->locale->date_format_long);

    ($year, $mon, $day) = split( /\-/, $c->session->{$section}->{end});
    $time = DateTime->new(year => $year, month => $mon, day => $day);
    $time->set_locale($c->language);
    $end = $time->format_cldr($time->locale->date_format_long);

    return {start => $start, end => $end};
}

=head2 _saveActiveGraph

=cut

sub _saveActiveGraph :Private {
    my ($self, $c) = @_;

    $c->session->{dashboard_activegraph} = $c->action->name;
}

=head2 _graphLine

=cut

sub _graphLine :Private {
    my ($self, $c, $title, $section) = @_;

    my $id = $title;
    $id =~ s/ //g;
    my ($status, $result) = $c->model('Graph')->timeBase($c->action->name,
                                                         $c->session->{$section}->{start},
                                                         $c->session->{$section}->{end},
                                                         { continuous => 0 });
    if (is_success($status)) {
        $c->stash({
                   id => $id,
                   section => $section,
                   title => $title,
                   range => $self->_range($c, $section),
                   labels => $result->{labels},
                   series => $result->{series},
                   graphtype => scalar @{$result->{labels}} > 1 ? 'line' : 'bar',
                   template => 'graph/line.tt',
                   current_view => 'HTML',
                  });
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }
}

=head2 _graphPie

=cut

sub _graphPie :Private {
    my ($self, $c, $title, $section, $options) = @_;

    my $id = $title;
    $id =~ s/ //g;
    $id =~ s/[\(\)]/-/g;
    my ($status, $result) = $c->model('Graph')->ratioBase($c->action->name,
                                                          $c->session->{$section}->{start},
                                                          $c->session->{$section}->{end},
                                                          $options);
    if (is_success($status)) {
        $c->stash({
                   id => $id,
                   title => $title,
                   range => $self->_range($c, $section),
                   label => $options->{fields}->{label},
                   value => $options->{fields}->{value} || $options->{fields}->{count},
                   option => $options->{option},
                   options => $options->{options},
                   labels => $result->{labels},
                   series => $result->{series},
                   values => $result->{values},
                   piecut => $result->{piecut},
                   graphtype => 'pie',
                   template => 'graph/pie.tt',
                   current_view => 'HTML'
                  });
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
    }
}

=head2 _graphCounter

=cut

sub _graphCounter :Private {
    my ($self, $c, $module, $title, $params) = @_;

    my $graph = {};
    my $id = $module . ucfirst $params->{value};
    $id =~ s/ //g;

    my ($status, $result) = $c->model('Graph')->countAll($module, $params);
    if (is_success($status)) {
        $graph->{title} = $title;
        $graph->{id} = $id;
        $graph->{count} = $result;
    }
    else {
        $c->log->error($result);
    }

    return $c->view('HTML')->render($c, 'graph/counter.tt', $graph);
}

=head2 _dashboardCounters

=cut

sub _dashboardCounters :Private {
    my ( $self, $c ) = @_;

    my $start = $c->session->{$DASHBOARD}->{start} . ' 00:00:00';
    my $end = $c->session->{$DASHBOARD}->{end} . ' 23:59:59';

    my $counters =
      {
       nodes_reg   => $self->_graphCounter($c, 'node', $GRAPH_REGISTERED_NODES,
                                           { type => 'status', value => 'reg',
                                             between => ['regdate', $start, $end] }),
       nodes_unreg => $self->_graphCounter($c, 'node', $GRAPH_UNREGISTERED_NODES,
                                           { type => 'status', value => 'unreg',
                                             between => ['unregdate', $start, $end] }),
       nodes_new   => $self->_graphCounter($c, 'node', $GRAPH_NEW_NODES,
                                           { value => 'detect',
                                             between => ['detect_date', $start, $end] }),
       violations  => $self->_graphCounter($c, 'violation', $GRAPH_VIOLATIONS,
                                           { value => 'violations',
                                             between => ['start_date', $start, $end] }),
       wired       => $self->_graphCounter($c, 'locationlog', $GRAPH_WIRED_CONNECTIONS,
                                           { value => 'wired',
                                             start_date => $start, end_date => $end }),
       wireless    => $self->_graphCounter($c, 'locationlog', $GRAPH_WIRELESS_CONNECTIONS,
                                           { value => 'wireless',
                                             start_date => $start, end_date => $end }),
      };

    return $counters;
}

=head2 index

=cut

sub index :Path : Args(0) {
    my ($self, $c) = @_;

    $c->response->redirect($c->uri_for($self->action_for('nodes')));
    $c->detach();
}

=head2 dashboard

=cut

sub dashboard :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $DASHBOARD, $start, $end);

    $c->stash->{counters} = $self->_dashboardCounters($c);
    unless ($c->session->{dashboard_activegraph}) {
        $c->session->{dashboard_activegraph} = $self->action_for('registered')->name;
    }

    my $now = time();
    my $today = POSIX::strftime("%Y-%m-%d", localtime($now));
    $c->stash({
               'last0day' => sprintf('%s/%s', $today, $today),
               'last7days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 7*24*60*60)), $today),
               'last30days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 30*24*60*60)), $today),
               'last60days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 60*24*60*60)), $today),
              });

    $c->stash->{current_view} = 'HTML';
}

=head2 reports

=cut

sub reports :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);

    my $now = time();
    my $today = POSIX::strftime("%Y-%m-%d", localtime($now));
    $c->stash({
               'last7days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 7*24*60*60)), $today),
               'last30days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 30*24*60*60)), $today),
               'last60days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 60*24*60*60)), $today),
               'last90days' => sprintf('%s/%s', POSIX::strftime("%Y-%m-%d", localtime($now - 90*24*60*60)), $today),
              });
}

=head2 registered

Number of new registered nodes per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_registered.

Used in the dashboard.

=cut

sub registered :Path('nodes/registered') :Args(2) :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_REGISTERED_NODES), $DASHBOARD);
}

=head2 unregistered

Number of new unregistered nodes per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_unregistered.

Used in the dashboard.

=cut

sub unregistered :Path('nodes/unregistered') :Args(2) :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_UNREGISTERED_NODES), $DASHBOARD);
}

=head2 detected

Number of new nodes detected per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_detected.

Used in the dashboard.

=cut

sub detected :Path('nodes/detected') :Args(2) :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_NEW_NODES), $DASHBOARD);
}

=head2 wired

Number of new wired connections per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_wired.

Used in the dashboard.

=cut

sub wired :Local :Args(2) :AdminRole('REPORTS') {
    my ( $self, $c, $start, $end ) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_WIRED_CONNECTIONS), $DASHBOARD);
}

=head2 wireless

Number of new wireless connections per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_wireless.

Used in the dashboard.

=cut

sub wireless :Local :Args(2) :AdminRole('REPORTS') {
    my ( $self, $c, $start, $end ) = @_;

    $self->_saveActiveGraph($c);
    #my $widget = (defined $c->request->params->{widget})? $c->request->params->{widget} : 0;
    $self->_graphLine($c, $c->loc($GRAPH_WIRELESS_CONNECTIONS), $DASHBOARD);
}

=head2 violations_all

Number of violations triggered per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_violations_all.

Used in the dashboard.

=cut

sub violations_all :Local :Args(2) :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_VIOLATIONS), $DASHBOARD);
}

=head2 nodes

Number of nodes by type (registered, unregistered, etc) per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_nodes.

Defined as a report.

=cut

sub nodes :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphLine($c, $c->loc('Nodes'), $REPORTS);

    $start = $c->session->{$REPORTS}->{start};
    $end = $c->session->{$REPORTS}->{end};

    if (0) {
        # TODO: activate and format counters
        my ($status, $result);
        my @counters = ();
        ($status, $result) = $c->model('Graph')->countAll('node', { type => 'status', value => 'unreg',
                                                                    between => ['unregdate', $start, $end] });
        if (is_success($status)) {
            push(@counters,
                 {
                  id => 'nodeStatusUnreg',
                  title => 'Unregistered',
                  count => $result,
                 }
                );
            $c->stash->{counters} = \@counters;
        }
        ($status, $result) = $c->model('Graph')->countAll('node', { type => 'status', value => 'reg',
                                                                    between => ['regdate', $start, $end] });
        if (is_success($status)) {
            push(@counters,
                 {
                  id => 'nodeStatusReg',
                  title => 'Registered',
                  count => $result,
                 }
                );
            $c->stash->{counters} = \@counters;
        }
    }
}

=head2 violations

Number of nodes by violation type per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_violations.

Defined as a report.

=cut

sub violations :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphLine($c, $c->loc('Violations'), $REPORTS);
}

=head2 os

Number of nodes by operating system for a specific period.

Tightly coupled to pf::pfcmd::report::report_os.

Defined as a report.

=cut

sub os :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Operating Systems'), $REPORTS,
                     {
                      fields => { label => 'description',
                                  count => 'count' },
                     }
                    );
}

=head2 connectiontype

Number of nodes by connection type (Wired SNMP, WiFi MAC Auth, Inline, etc) for a specific period.

Tightly coupled to pf::pfcmd::report::report_connectiontype.

Defined as a report.

=cut

sub connectiontype :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Connections Types'), $REPORTS,
                     { fields => { label => 'connection_type',
                                   'count' => 'connections' },
                     }
                    );
}

=head2 ssid

Number of nodes by SSID for a specific period.

Tightly coupled to pf::pfcmd::report::report_ssid.

Defined as a report.

=cut

sub ssid :Local :AdminRole('REPORTS') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('SSID'), $REPORTS,
                     { fields => { label => 'ssid',
                                   count => 'nodes' },
                     }
                    );
}

=head2 nodebandwidth

Bandwidth usage by node for a specific period.

Tightly coupled to pf::pfcmd::report::report_nodebandwidth.

Defined as a report.

=cut

sub nodebandwidth :Local :AdminRole('REPORTS') {
    my ($self, $c, $option, $start, $end) = @_;

    $option = 'accttotal' unless ($option && $option =~ m/^(accttotal|acctinput|acctoutput)$/);

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Bandwidth Consumers'), $REPORTS,
                     { fields => { label => 'callingstationid',
                                   count => $option."octets",
                                   value => $option },
                       options => ['accttotal', 'acctinput', 'acctoutput'],
                       option => $option }
                    );
}

=head2 osclassbandwidth

Bandwidth usage by OS class for a specific period.

Tightly coupled to pf::pfcmd::report::report_osclassbandwidth.

Defined as a report.

=cut

sub osclassbandwidth :Local :AdminRole('REPORTS') {
    my ( $self, $c, $start, $end ) = @_;

    my $option = 'accttotal'; # we only sypport this field, see pf::pfcmd::report

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Bandwidth per Operating System Class'), $REPORTS,
                     { fields => { label => 'dhcp_fingerprint',
                                   count => $option."octets",
                                   value => $option },
                     });
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
