<div id="[%id%]" class="btn-group">
  <a id="bulk_actions" class="btn btn-link btn-small dropdown-toggle" data-toggle="dropdown">
    <i class="icon-cog"></i> [% l('Action') %]
    <i class="icon-angle-down"></i>
  </a>
  <ul class="dropdown-menu">
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_close'))  %]" >[% l('Clear Security Event') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_register'))  %]" >[% l('Register') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_deregister'))  %]">[% l('Deregister') %]</a></li>
    [% IF bulk_type == 'node' %]
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_reevaluate_access'))  %]">[% l('Reevaluate access') %]</a></li>
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_restart_switchport'))  %]">[% l('Restart Switchport') %]</a></li>
    [% END %]
    [% IF bulk_type == 'user' %]
    <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_delete'))  %]">[% l('Delete') %]</a></li>
    [% END %]
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
      <a  tabindex="-1">[% l('Apply Security Event') %]</a>
      <ul class="dropdown-menu" id="apply_security_events">
        [% FOREACH security_event IN security_events %]
        [% NEXT IF security_event.id =='default' || security_event.enabled != 'Y'%]
        <li class="disabled"><a class="bulk_action" data-target="[% c.uri_for(c.controller.action_for('bulk_apply_security_event'),[security_event.id])  %]">[% security_event.desc %]</a></li>
        [% END %]
      </ul>
    </li>
  </ul>
</div>
