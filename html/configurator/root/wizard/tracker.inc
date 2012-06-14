      <div id="tracker" class="row">
        <div class="span9 offset3">
              <ul class="nav nav-pills">
                <li[% IF step == 1 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step1') %]" rel="tooltip" title="Choose your enforcement mechanisms"><i class="icon-step1"></i> <span>Enforcement</span></a>
                </li>
                <li[% IF step == 2 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step2') %]"  rel="tooltip" title="Configure network interfaces" ><i class="icon-step2"></i> <span>Networks</span></a>
                </li>
                <li[% IF step == 3 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step3') %]"  rel="tooltip" title="Configure MySQL" ><i class="icon-step3"></i> <span>Database</span></a>
                </li>
                <li[% IF step == 4 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step4') %]" rel="tooltip" title="Configure various options"><i class="icon-step4"></i> <span>PacketFence</span></a>
                </li>
                <li[% IF step == 5 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step5') %]" rel="tooltip" title="Configure access to the admin interface"><i class="icon-step5"></i> <span>Administration</span></a>
                </li>
                <li[% IF step == 6 %] class="active"[% END %]>
                  <a href="[% c.uri_for('step6') %]" rel="tooltip" title="Start the services"><i class="icon-step6"></i> <span>Confirmation</span></a>
                </li>
              </ul>
        </div>
      </div>
