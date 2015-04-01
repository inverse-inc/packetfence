<div id="[%id%]" class="btn-group">
  <a id="bulk_actions" class="btn btn-link btn-small dropdown-toggle" data-toggle="dropdown" href="#">
    <i class="icon-cog"></i> [% l('Action') %]
    <i class="icon-angle-down"></i>
  </a>
  <ul class="dropdown-menu">
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_close'))  %]" >[% l('Clear Violation') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_register'))  %]" >[% l('Register') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_deregister'))  %]">[% l('Deregister') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_reevaluate_access'))  %]">[% l('Reevaluate access') %]</a></li>
    <li class="divider"></li>
    <li class="dropdown-submenu">
      <a tabindex="-1">[% l('Apply Role') %]</a>
      <ul class="dropdown-menu" id="apply_roles">
        [% FOREACH role IN roles %]
        <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_apply_role'),[role.category_id])  %]">[% role.name %]</a></li>
        [% END %]
      </ul>
    </li>
    [% IF bulk_type == 'node' %]
        <li class="divider"></li>
        <li class="dropdown-submenu">
          <a tabindex="-1">[% l('Apply Bypass Role') %]</a>
          <ul class="dropdown-menu" id="apply_roles">
            [% FOREACH role IN roles %]
            <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_apply_bypass_role'),[role.category_id])  %]">[% role.name %]</a></li>
            [% END %]
          </ul>
        </li>
    [% END %]
    <li class="divider"></li>
    <li class="dropdown-submenu">
      <a  tabindex="-1">[% l('Apply Violation') %]</a>
      <ul class="dropdown-menu" id="apply_violations">
        [% FOREACH violation IN violations %]
        [% NEXT IF violation.id =='default' || violation.enabled != 'Y'%]
        <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_apply_violation'),[violation.id])  %]">[% violation.desc %]</a></li>
        [% END %]
      </ul>
    </li>
  </ul>
</div>
