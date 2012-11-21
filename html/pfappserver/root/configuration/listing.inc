[% MACRO header(column, title) BLOCK -%]
[% params = { by => column, filter => filter };
    IF by == column && direction == 'asc';
      params.direction = 'desc';
    END %]
                  <th><a href="[% c.uri_for(c.action.name, params) %]">[% title %][% IF by == column %] <i class="icon-chevron-[% IF direction == 'desc' %]down[% ELSE %]up[% END %]"></i>[% END %]</a></th>
[% END -%]
        <div>
          <form name="simpleSearch" class="form-inline" action="[% c.uri_for(c.action.name) %]">
              <div class="btn-group pull-right">
                 <input id="simpleString" type="text" placeholder="Search...">
                <button class="btn btn-primary"><i class="icon-search icon-white"></i> Search</button>
              </div>
          </form>
        </div>
        <br/>
    [% INCLUDE 'configuration/pagination.inc' IF items.size > 0 %]

            <div class="pagination pagination-right">
                <table class="table table-condensed table-striped">
                  <thead>
                    <tr>
                    [%- FOREACH field IN field_names -%]
                      [% header(field, titles.$field) %]
                    [%- END -%]
                    </tr>
                  </thead>
                  <tbody>
                    [%- FOREACH item IN items -%]
                    <tr>
                        [%- FOREACH field IN field_names -%]
                      <td>[% item.$field %]</td>
                        [%- END -%]
                    </tr>
                    [%- END -%]
                  </tbody>
                </table>
            </div>
[% INCLUDE 'configuration/pagination.inc' IF items.size > 0 %]
