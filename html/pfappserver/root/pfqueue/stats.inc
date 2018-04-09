[%- MACRO show_stats(stats, show_graphs) BLOCK -%]
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

  [% IF show_graphs %]
  <div>
    <h5>[% queue_counts_graph.description %]</h5>
    <span class="graph graph-2c">
      <img src="[% queue_counts_graph.url %]" height="[% queue_counts_graph.height %]" width="[% queue_counts_graph.width %]">
    </span>
  </div>
  [% END %]

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
[% END %]
