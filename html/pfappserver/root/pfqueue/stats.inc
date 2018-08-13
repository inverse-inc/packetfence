[%- MACRO show_graphs_stats(stats, host, ip) BLOCK -%]
<div class="card">
  <div class="card-title">
      <h2>[% l('Queue stats') %]</h2>
  </div>
[% FOREACH counter IN stats.queue_counts %]
  <div class="card-block">
      <div class="row-fluid">
          <div class="spangridSize text-center">
              <div data-netdata="statsd_gauge_[% host.replace('\.|-','_') %].pfqueue.stats.queue_counts.[% counter.name %]"
              data-host="/netdata/[% ip %]"
              data-title="[% counter.name %] queue count"
              data-chart-library="dygraph"
              data-colors="[% palette(loop.index) %]"
              data-height="200px"
              data-hide-missing="true"
              data-dimensions="gauge"
              data-before="0"
              data-after="-86400"></div>
          </div>
      </div>
  </div>
    [% END %]
</div>
[% END %]

[%- MACRO show_stats(stats, show_graphs, host, ip) BLOCK -%]
<div class="card-block">
  <table class="table table-condensed table-striped">
    <thead>
      <tr><th colspan="3">[%l('Queue Counts')%]</th></tr>
      <tr>
        <th>[% l('Queue') %]</th>
        <th width="30%">[% l('Count') %]</th>
      </tr>
    </thead>

    [% FOREACH counter IN stats.queue_counts %]
      <tr>
        <td> [% counter.name %]</td>
        <td> [% counter.count %]</td>
      </tr>
    [% END %]
    
  </table>

  [% IF stats.counters.size > 0 %]
  <table class="table table-condensed table-striped">
    <thead>
      <tr><th colspan="3">[%l('Outstanding Task Counters')%]</th></tr>
      <tr>
        <th width="30%">[% l('Queue') %]</th>
        <th>[% l('Task type') %]</th>
        <th width="30%">[% l('Count') %]</th>
      </tr>
    </thead>
    [% FOREACH counter IN stats.counters %]
      <tr>
        <td> [% counter.queue %]</td>
        <td>[% counter.name %] </td>
        <td> [% counter.count %]</td>
      </tr>
    [% END %]
  </table>
  [% ELSE %]
  <div class="unwell">
   <p> <i class="icon-group icon-large"></i>
     [% l('No Task Counters.') %]
   </p>
  </div>
  [% END %]
  [% IF stats.miss_counters.size > 0 %]
  <table class="table table-condensed table-striped">
    <thead>
      <tr><th colspan="3">[%l('Expired Task Counters')%]</th></tr>
      <tr>
        <th width="30%">[% l('Queue') %]</th>
        <th>[% l('Task type') %]</th>
        <th width="30%">[% l('Count') %]</th>
      </tr>
    </thead>
    [% FOREACH counter IN stats.miss_counters %]
      <tr>
        <td>[% counter.queue %]</td>
        <td>[% counter.name %] </td>
        <td>[% counter.count %]</td>
      </tr>
    [% END %]
  </table>
  [% ELSE %]
    <tr>
      <td colspan="3">
      <div class="unwell">
       <p> <i class="icon-group icon-large"></i>
         [% l('No Expired Task Counters.') %]
       </p>
      </div>
      </td>
    </tr>
  [% END %]
</div>

[% IF show_graphs %]
[% show_graphs_stats(stats, host, ip) | none %]
[% END %]

[% END %]
