[% IF page_num -%]
[% params = { by => by, direction => direction, filter => filter, per_page => per_page } %]
            <div class="pagination pagination-right">
              <ul>
              [% IF page_num > 1 -%]
                [% params.page_num = page_num - 1 -%]
                <li><a href="[% c.uri_for(c.action.name, params) %]">&larr;</a></li>
              [% END -%]
              [%- first_page = page_num - 3;
                  IF first_page < 1; first_page = 1; END;
                  last_page = first_page + 6;
                  IF last_page > pages_count;
                    last_page = pages_count;
                    first_page = last_page - 6;
                    IF first_page < 1; first_page = 1; END;
                  END %]
              [%- IF first_page > 1 -%]
                [% params.page_num = 1 -%]
                <li><a href="[% c.uri_for(c.action.name, params) %]" title="Page 1">1</a></li>
                <li class="disabled"><a href="#">…</a></li>
              [%- END -%]
              [% page = first_page; WHILE page <= last_page -%]
                [% params.page_num = page %]
                <li[% IF page == page_num %] class="active"[% END %]><a href="[% c.uri_for(c.action.name, params) %]">[% page %]</a></li>
                [%- page = page + 1 -%]
              [%- END -%]
              [%- IF last_page < pages_count -%]
                [% params.page_num = pages_count %]
                <li class="disabled"><a href="#">…</a></li>
                <li><a href="[% c.uri_for(c.action.name, params) %]" title="Page [% pages_count %]">[% pages_count %]</a></li>
              [%- END -%]
              [%- IF page_num < page - 1 -%]
                [% params.page_num = page_num + 1 %]
                <li><a href="[% c.uri_for(c.action.name, params) %]">&rarr;</a></li>
              [%- END %]
              </ul>
            </div>
[%- END %]