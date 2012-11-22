[% MACRO header(column, title) BLOCK -%]
[% params = { by => column, filter => filter };
    IF by == column && direction == 'asc';
      params.direction = 'desc';
    END %]
                  <th><a href="[% c.uri_for(c.action.name, params) %]">[% title %][% IF by == column %] <i class="icon-chevron-[% IF direction == 'desc' %]down[% ELSE %]up[% END %]"></i>[% END %]</a></th>
[% END -%]
        <div>
          <form name="simpleSearch" class="form-search" action="[% c.uri_for(c.action.name) %]">
              <div class="pull-right">
                 <input id="simpleString" class="search-query" type="text" placeholder="Search..." value="[% filter | html  %]"</input>
                 <button class="btn btn-primary"><i class="icon-search icon-white"></i></button>
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
