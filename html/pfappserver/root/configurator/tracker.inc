      <div id="tracker" class="row">
        <div class="span9 offset3">
              <ul class="nav nav-pills">
              [% FOREACH step IN steps -%]
                <li[% IF step.id == c.action.name %] class="active"[% END %]>
                  <a href="[% c.uri_for(step.id) %]" rel="tooltip" title="[% l(step.description) %]"><i>&#101[% loop.index + 22 %];</i> <span>[% l(step.title) %]</span></a>
                </li>
              [%- END -%]
              </ul>
        </div>
      </div>
