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
use URI::Escape::XS qw(uri_escape uri_unescape);
use namespace::autoclean;
use pf::config qw(
    $management_network
    %Config
    %ConfigReport
    @listen_ints
);
use pfconfig::cached_array;
use pf::cluster;
use pf::nodecategory;
use Sys::Hostname;
use pf::config::cluster;
DateTime::Locale->add_aliases({
    'i_default' => 'en',
});

BEGIN { extends 'pfappserver::Base::Controller'; }

Readonly::Scalar our $DASHBOARD => 'dashboard';
Readonly::Scalar our $REPORTS => 'reports';

Readonly::Scalar our $GRAPH_REGISTERED_NODES => 'Registered Nodes';
Readonly::Scalar our $GRAPH_UNREGISTERED_NODES => 'Unregistered Nodes';
Readonly::Scalar our $GRAPH_NEW_NODES => 'New Nodes';
Readonly::Scalar our $GRAPH_SECURITY_EVENTS => 'Security Events';
Readonly::Scalar our $GRAPH_WIRED_CONNECTIONS => 'Wired Connections';
Readonly::Scalar our $GRAPH_WIRELESS_CONNECTIONS => 'Wireless Connections';
Readonly::Array our @GRAPHS =>
  (
   $GRAPH_REGISTERED_NODES,
   $GRAPH_UNREGISTERED_NODES,
   $GRAPH_NEW_NODES,
   $GRAPH_SECURITY_EVENTS,
   $GRAPH_WIRED_CONNECTIONS,
   $GRAPH_WIRELESS_CONNECTIONS
  );

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";

=head1 METHODS

=head2 begin

Set the default view to pfappserver::View::JSON.

=cut

sub begin :Private {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    $self->_rangeForHeader($c);
}

=head2 _saveRange

Save the period range for a specific section.

=cut

sub _saveRange :Private {
    my ($self, $c, $section, $start, $end) = @_;

    if ( ( defined $start and defined $end )
            and length $start && length $end ) {
        if (my ($syear, $smonth, $sday) = $start =~ m/(\d{4})-?(\d{1,2})-?(\d{1,2})/) {
            if (my ($eyear, $emonth, $eday) = $end =~ m/(\d{4})-?(\d{1,2})-?(\d{1,2})/) {
                $c->session->{$section}->{start} = sprintf("%i-%02i-%02i", $syear, $smonth, $sday);
                $c->session->{$section}->{end} = sprintf("%i-%02i-%02i", $eyear, $emonth, $eday);
            }
        }
    }
    elsif ($section eq $DASHBOARD) {
        my ($count, $unit, $base) = (0, undef, 0);
        if ($start && $start =~ m/^\-(\d+)([hdwm])$/) {
            # Format session start/end dates according to a relative date
            ($count, $unit) = ($1, $2);
            if    ($unit eq 'h') { $base = 0; }
            elsif ($unit eq 'd') { $base = 1; }
            elsif ($unit eq 'w') { $base = 7; }
            elsif ($unit eq 'm') { $base = 31; }
        }
        $c->session->{$section}->{start} = POSIX::strftime( "%Y-%m-%d", localtime(time() - $base*$count*24*60*60 ) );
        $c->session->{$section}->{end} = POSIX::strftime( "%Y-%m-%d", localtime() );
    }
    else {
        unless ($c->session->{$section}->{start} && $c->session->{$section}->{end}) {
            # Default to the last 7 days for the dashboard, 30 for the reports
            my $days = 30;
            $c->session->{$section}->{start} = POSIX::strftime( "%Y-%m-%d", localtime(time() - $days*24*60*60 ) );
            $c->session->{$section}->{end} = POSIX::strftime( "%Y-%m-%d", localtime() );
        }
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
                   items  => $result->{items},
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
       security_events  => $self->_graphCounter($c, 'security_event', $GRAPH_SECURITY_EVENTS,
                                           { value => 'security_events',
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

=head2 _buildGraphiteURL

Build the image source URL to retrieve a graph from the Graphite server.

=cut

sub _buildGraphiteURL :Private {
    my ($self, $c, $start, $width, $params) = @_;

    my $management_ip =
      defined( $management_network->tag('vip') )
      ? $management_network->tag('vip')
      : $management_network->tag('ip');

    if (!$width) {
        $width = 1170;
    }

    if ($params->{columns} == 1) {
        $params->{width} = int($width/2 + 0.5) - 8;
    } elsif ($params->{columns} == 2) {
        $params->{width} = $width;
    }

    unless ($start =~ m/^\-/) {
        if ($c->session->{$DASHBOARD}->{start} eq $c->session->{$DASHBOARD}->{end}) {
            # Default to the last 24 hours when the start and end date are the same
            $start = '-1d';
        }
        else {
            # When dealing with an absolute range, format the dates as expected by Graphite
            my ($sec,$min,$hour,$day,$mon,$year) = localtime(time);
            # Format start (from)
            ($year, $mon, $day) = split( /\-/, $c->session->{$DASHBOARD}->{start});
            $start = sprintf('%02d:%02d_%04d%02d%02d', $hour, $min, $year, $mon, $day);
            # Format end (until)
            ($year, $mon, $day) = split( /\-/, $c->session->{$DASHBOARD}->{end});
            $params->{until} = sprintf('%02d:%02d_%04d%02d%02d', $hour, $min, $year, $mon, $day);
        }
    }

    $params->{from} = $start;
    $params->{format} = 'png';
    $params->{tz} = 'Etc/UTC';
    $params->{tz} = $Config{'general'}{'timezone'};
    $params->{height} = '320';
    $params->{bgcolor} = 'ff000000';
    $params->{fgcolor} = '#000000'; #'#B8B8B8';
    $params->{majorGridLineColor} = '#505050';
    $params->{minorGridLineColor} = '#454545';
    $params->{hideLegend} = 'false';
    $params->{hideAxes} = 'false';
    $params->{colorList} = '#1f77b4,#ff7f0e,#2ca02c,#d62728,#9467bd,#8c564b,#e377c2,#7f7f7f,#bcbd22,#17becf';

    my $url = sprintf('./metrics/render?%s',
                      join('&', map { $_ . '=' . uri_escape($params->{$_}) }
                          grep { $_ ne "target" } grep { $_ ne "description" } keys(%$params))); # we don't map the target here. It can be an arrayref

    # targets can be an arrayref of graphite queries, so we need to handle it
    if (ref $params->{'target'} eq  "ARRAY") {
        for my $target ( @{ $params->{'target'} }) {
            $url .=  ( '&target=' . uri_escape( $target ));
        }
    }
    else {
        $url .= ( '&target=' . uri_escape( $params->{'target'} ) );
    }

    return $url;
}

=head2 dashboard

=cut

sub dashboard :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;
    my $width = $c->request->param('width');
    my $tab = $c->request->param('tab') // 'system';
    tie my @authentication_sources_monitored, 'pfconfig::cached_array', "resource::authentication_sources_monitored";
    my @categories = pf::nodecategory::nodecategory_view_all();
    $start //= '';

    $self->_saveRange($c, $DASHBOARD, $start, $end);

    my @graphs = (
        {
            'description' => $c->loc('Registrations/min'),
            'target'      => [
'alias(groupByNode(summarize(stats.counters.*.pf__node__node_register.called.count,"1min"),5,"sum"),"End-Points registered")',
'alias(groupByNode(summarize(stats.counters.*.pf__node__node_deregister.called.count,"1min"),5,"sum"), "End-Points deregistered")'
            ],
            'lineMode' => "staircase",
            'columns'  => 2,
        },
        {
            'description' => $c->loc('RADIUS Total Access-Requests/s'),
            'vtitle'      => 'requests',
            'target' =>
'alias(sum(*.radsniff-exchanged.radius_count-access_request.received),"Access-Requests")',
            'columns' => 1
        },
        {
            'description' => $c->loc('RADIUS Access-Requests/s per server'),
            'vtitle'      => 'requests',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_count-access_request.received,0)',
            'columns' => 1
        },
        {
            'description' => $c->loc('RADIUS Access-Accepts/s per server'),
            'vtitle'      => 'replies',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_count-access_accept.received,0)',
            'columns' => 2
        },
        {
            'description' => $c->loc('RADIUS Access-Rejects/s per server'),
            'vtitle'      => 'replies',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_count-access_reject.received,0)',
            'columns' => 2
        },
        {
            'description' => $c->loc('Apache AAA call timing'),
            'vtitle'      => 'ms',
            'target' =>
'aliasByNode(stats.timers.*.pf__api__radius_rest_authorize.timing.mean_90,2)',
            'columns' => 1
        },
        {
            'description' => $c->loc('Apache AAA Open Connections per server'),
            'vtitle'      => 'connections',
            'target'      => 'aliasByNode(*.apache-aaa.apache_connections,0)',
            'columns'     => 1
        },
        {
            'description' => $c->loc('NTLM call timing'),
            'vtitle'      => 'ms',
            'target'  => 'aliasByNode(stats.timers.*.ntlm_auth.time.mean_90,2)',
            'columns' => 1
        },
        {
            'description' => $c->loc('NTLM authentication failures'),
            'vtitle'      => 'failures/s',
            'target'      => [
'aliasSub(stats.counters.*.ntlm_auth.failures.count,"^stats.counters.([^.]+).ntlm_auth.failures.count$", "\1 failures")',
                _generate_timeout_group()
            ],
            'columns'        => 1,
            'drawNullAsZero' => 'true'
        },
        {
            'description' => $c->loc('Portal Open Connections per server'),
            'vtitle'      => 'connections',
            'target'  => 'aliasByNode(*.apache-portal.apache_connections,0)',
            'columns' => 1
        },
        {
            'description' =>
              $c->loc('Apache Webservices Open Connections per server'),
            'vtitle' => 'connections',
            'target' =>
              'aliasByNode(*.apache-webservices.apache_connections,0)',
            'columns' => 1
        },
        {
            'description' => $c->loc('RADIUS Average Access-Request Latency'),
            'vtitle'      => 'ms',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_latency-access_request.smoothed,0)',
            'columns' => 1
        },
        {
            'description' => $c->loc('PF Database Threads'),
            'vtitle'      => 'threads',
            'target'      => 'aliasByNode(*.mysql-pf.threads-*,2)',
            'columns'     => 1
        },
        {
            'description' => $c->loc('RADIUS Accounting requests received/s'),
            'vtitle'      => 'requests',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_count-accounting_request.received,0)',
            'columns' => 1
        },
        {
            'description' => $c->loc('RADIUS Accounting Latency'),
            'vtitle'      => 'ms',
            'target' =>
'aliasByNode(*.radsniff-exchanged.radius_latency-accounting_request.smoothed,0)',
            'columns' => 1
        },
    );

    foreach my $graph (@graphs) {
#        $graph->{url} = $self->_buildGraphiteURL($c, $start, $width, $graph);
    }

    $c->stash(
        graphs         => \@graphs,
        hostname       => $pf::cluster::host_id,
        cluster        => { map { $_->{host} => $_->{management_ip} } @config_cluster_servers },
        sources        => \@authentication_sources_monitored,
        roles          => \@categories,
        current_view   => 'HTML',
        tab            => $tab,
        networks       => \%NetworkConfig,
        listen_ints    => \@listen_ints,
        queue_stats    => $c->model('Pfqueue')->stats,
    );
}

=head2 systemstate

=cut

sub systemstate :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;
    my $graphs = [];
    my $width = $c->request->param('width');
    $start //= '';

    $self->_saveRange($c, $DASHBOARD, $start, $end);

    $graphs = [
               {
                'description' => $c->loc('Server Load'),
                'target' => 'aliasByNode(*.load.load.midterm,0)',
                'columns' => 2
               },
               {
                'description' => $c->loc('CPU Wait'),
                'target' => 'aliasByNode(*.*.cpu-wait,0,1)',
                'columns' => 2
               },
               {
                'description' => $c->loc('Disk IO Time'),
                'target' => 'aliasByNode(*.*.disk_io_time.io_time,0,1)',
                'columns' => 2
               },
               {
                'description' => $c->loc('Available Memory'),
                'target' => 'groupByNode(*.memory.memory-{free,cached,buffered}, 0, "sumSeries") ',
                'columns' => 2
               },
               {
                'description' => $c->loc('Available Swap'),
                'target' => 'aliasByNode(*.swap.swap-free, 0) ',
                'columns' => 2
               },
               {
                'description' => $c->loc('Conntrack percent used'),
                'target' => 'aliasByNode(*.conntrack.percent-used,0)',
                'columns' => 2
               },
              ];

    foreach my $graph (@$graphs) {
        $graph->{url} = $self->_buildGraphiteURL($c, $start, $width, $graph);
    }
    $c->stash->{graphs} = $graphs;
    $c->stash->{current_view} = 'HTML';
}


=head2 logstate

=cut

sub logstate :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;
    my $graphs = [];
    my $width = $c->request->param('width');
    $start //= '';

    $self->_saveRange($c, $DASHBOARD, $start, $end);

    $graphs = [
               {
                'description' => $c->loc('Logs Tracking packetfence.log'),
                'target' => '*.tail-PacketFence.counter*',
                'columns' => 2
               },
               {
                'description' => $c->loc('Logs Tracking pfmon.log'),
                'target' => '*.tail-pfmon.counter*',
                'columns' => 2
               },
               {
                'description' => $c->loc('Logs Tracking pfdhcplistener.log'),
                'target' => '*.tail-pfdhcplistener.counter*',
                'columns' => 2
               },
               {
                'description' => $c->loc('Logs Tracking radius-load_balancer.log'),
                'target' => '*.tail-radius-load_balancer.counter*',
                'columns' => 2
               },
               {
                'description' => $c->loc('Logs Tracking radius.log'),
                'target' => '*.tail-radius-auth.counter*',
                'columns' => 2
               }
              ];

    foreach my $graph (@$graphs) {
        $graph->{url} = $self->_buildGraphiteURL($c, $start, $width, $graph);
    }
    $c->stash->{graphs} = $graphs;
    $c->stash->{current_view} = 'HTML';
}

=head2 reports

=cut

sub reports :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    my @builtin_report_ids = sort { $ConfigReport{$a}->{description} cmp $ConfigReport{$b}->{description} } map { $ConfigReport{$_}->{type} eq "builtin" ? $_ : () } keys %ConfigReport;
    my @custom_report_ids = sort { $ConfigReport{$a}->{description} cmp $ConfigReport{$b}->{description} } map { $ConfigReport{$_}->{type} ne "builtin" ? $_ : () } keys %ConfigReport;
    $c->stash->{builtin_report_ids} = \@builtin_report_ids;
    $c->stash->{custom_report_ids} = \@custom_report_ids;
    $c->stash->{dynamic_reports} = \%ConfigReport;

    $self->_saveRange($c, $REPORTS, $start, $end);

}

=head2 _rangeForHeader

=cut

sub _rangeForHeader {
    my ($self, $c) = @_;
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

sub registered :Path('nodes/registered') :Args(2) :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_REGISTERED_NODES), $DASHBOARD);
}

=head2 unregistered

Number of new unregistered nodes per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_unregistered.

Used in the dashboard.

=cut

sub unregistered :Path('nodes/unregistered') :Args(2) :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_UNREGISTERED_NODES), $DASHBOARD);
}

=head2 detected

Number of new nodes detected per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_detected.

Used in the dashboard.

=cut

sub detected :Path('nodes/detected') :Args(2) :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_NEW_NODES), $DASHBOARD);
}

=head2 wired

Number of new wired connections per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_wired.

Used in the dashboard.

=cut

sub wired :Local :Args(2) :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_WIRED_CONNECTIONS), $DASHBOARD);
}

=head2 wireless

Number of new wireless connections per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_wireless.

Used in the dashboard.

=cut

sub wireless :Local :Args(2) :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;

    $self->_saveActiveGraph($c);
    #my $widget = (defined $c->request->params->{widget})? $c->request->params->{widget} : 0;
    $self->_graphLine($c, $c->loc($GRAPH_WIRELESS_CONNECTIONS), $DASHBOARD);
}

=head2 security_events_all

Number of security_events triggered per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_security_events_all.

Used in the dashboard.

=cut

sub security_events_all :Local :Args(2) :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveActiveGraph($c);
    $self->_graphLine($c, $c->loc($GRAPH_SECURITY_EVENTS), $DASHBOARD);
}

=head2 nodes

Number of nodes by type (registered, unregistered, etc) per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_nodes.

Defined as a report.

=cut

sub nodes :Local :AdminRole('REPORTS_READ') {
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

=head2 security_events

Number of nodes by security_event type per day for a specific period.

Tightly coupled to pf::pfcmd::graph::graph_security_events.

Defined as a report.

=cut

sub security_events :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphLine($c, $c->loc('Security Events'), $REPORTS);
}

=head2 os

Number of nodes by operating system for a specific period.

Tightly coupled to pf::pfcmd::report::report_os.

Defined as a report.

=cut

sub os :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Operating Systems'), $REPORTS,
                     {
                      fields => { label => 'description',
                                  count => 'count' },
                     }
                    );
    $self->_add_links($c, 'device_type', 'equal', 'label');

}

=head2 connectiontype

Number of nodes by connection type (Wired SNMP, WiFi MAC Auth, Inline, etc) for a specific period.

Tightly coupled to pf::pfcmd::report::report_connectiontype.

Defined as a report.

=cut

sub connectiontype :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Connections Types'), $REPORTS,
                     { fields => { label => 'connection_type',
                                   'count' => 'connections' },
                     }
                    );
    $self->_add_links($c, 'connection_type', 'equal', 'connection_type_orig');
}

=head2 ssid

Number of nodes by SSID for a specific period.

Tightly coupled to pf::pfcmd::report::report_ssid.

Defined as a report.

=cut

sub ssid :Local :AdminRole('REPORTS_READ') {
    my ($self, $c, $start, $end) = @_;

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('SSID'), $REPORTS,
                     { fields => { label => 'ssid',
                                   count => 'nodes' },
                     }
                    );
    $self->_add_links($c, 'ssid', 'equal', 'label');
}

=head2 nodebandwidth

Bandwidth usage by node for a specific period.

Tightly coupled to pf::pfcmd::report::report_nodebandwidth.

Defined as a report.

=cut

sub nodebandwidth :Local :AdminRole('REPORTS_READ') {
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
    $self->_add_links($c, 'mac', 'equal', 'label');
}


=head2 _add_links


=cut

sub _add_links {
    my ($self, $c, $name, $op, $value_key) = @_;
    my $items = $c->stash->{items};
    if ($items) {
        for my $item (@$items) {
            $item->{link} = "/admin/nodes#/node/advanced_search?searches.0.name=$name&searches.0.op=$op&searches.0.value=" . $item->{$value_key};
        }
    }
    return ;
}


=head2 osclassbandwidth

Bandwidth usage by OS class for a specific period.

Tightly coupled to pf::pfcmd::report::report_osclassbandwidth.

Defined as a report.

=cut

sub osclassbandwidth :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;

    my $option = 'accttotal'; # we only support this field

    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Bandwidth per Operating System Class'), $REPORTS,
                     { fields => { label => 'dhcp_fingerprint',
                                   count => $option."octets",
                                   value => $option },
                     });
    $self->_add_links($c, 'dhcp_fingerprint', 'equal', 'label');
}

=head2 topauthenticationfailures_by_mac

Radius AAA errors by mac for a specific period.

Defined as a report.

=cut

sub topauthenticationfailures_by_mac :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Failures'), $REPORTS,
                     { fields => { label => 'mac',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'mac', 'equal', 'label');
}

=head2 topauthenticationfailures_by_ssid

Radius AAA errors by ssid for a specific period.

Defined as a report.

=cut

sub topauthenticationfailures_by_ssid :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Failures'), $REPORTS,
                     { fields => { label => 'ssid',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'ssid', 'equal', 'label');
}

=head2 topauthenticationfailures_by_username

Radius AAA errors by username for a specific period.

Defined as a report.

=cut

sub topauthenticationfailures_by_username :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Failures'), $REPORTS,
                     { fields => { label => 'user_name',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'person_name', 'equal', 'label');
}

=head2 topauthenticationsuccesses_by_mac

Radius AAA successes by mac for a specific period.

Defined as a report.

=cut

sub topauthenticationsuccesses_by_mac :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Successes'), $REPORTS,
                     { fields => { label => 'mac',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'mac', 'equal', 'label');
}

=head2 topauthenticationsuccesses_by_ssid

Radius AAA successes by ssid for a specific period.

Defined as a report.

=cut

sub topauthenticationsuccesses_by_ssid :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Successes'), $REPORTS,
                     { fields => { label => 'ssid',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'ssid', 'equal', 'label');
}

=head2 topauthenticationsuccesses_by_username

Radius AAA successes by username for a specific period.

Defined as a report.

=cut

sub topauthenticationsuccesses_by_username :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Successes'), $REPORTS,
                     { fields => { label => 'user_name',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'person_name', 'equal', 'label');
}

=head2 topauthenticationsuccesses_by_computername

Radius AAA successes by computername for a specific period.

Defined as a report.

=cut

sub topauthenticationsuccesses_by_computername :Local :AdminRole('REPORTS_READ') {
    my ( $self, $c, $start, $end ) = @_;
    $self->_saveRange($c, $REPORTS, $start, $end);
    $self->_graphPie($c, $c->loc('Top Authentication Successes'), $REPORTS,
                     { fields => { label => 'computer_name',
                                   count => 'count',
                                   value => 'count' },
                     });
    $self->_add_links($c, 'computername', 'equal', 'label');
}



sub _generate_hosts {
    my @hosts;
    if (@cluster_hosts) {
        @hosts = @cluster_hosts;
    }
    elsif ($Config{'graphite'}{'graphite_hosts'}) {

    }
    else {
        my $host = hostname;
        push @hosts, $host;
    }
    map {  s/\./_/g } @hosts;
    return @hosts;
}

sub _generate_timeout_group {
    my @group_members;
    for my $host (_generate_hosts()) {
        push @group_members,
                         "removeBelowValue(diffSeries(stats.counters.$host.freeradius__main__authenticate.count.count,stats.timers.$host.ntlm_auth.time.count),0)"
;
    } 

    return 'aliasSub(aliasByNode( group(' . join( ', ', @group_members ) . ') ,2), "^(\w+)", "\1 timeouts"  ) ';
}


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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
