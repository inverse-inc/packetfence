[% IF page_num -%]
            <div class="pagination pagination-right">
              <ul>
                [% IF page_num > 1 %]<li><a href="[% c.uri_for(c.action.name) %]?page_num=[% page_num - 1 %]&per_page=[% per_page %]">&larr;</a></li>[% END -%]
                [%- first_page = page_num - 3 %]
                [%- IF first_page < 1 %][% first_page = 1 %][% END %]
                [%- last_page = first_page + 6 %]
                [%- IF last_page > pages_count %][% last_page = pages_count; first_page = last_page - 6 %]
                  [% IF first_page < 1 %][% first_page = 1 %][% END %]
                [% END %]
                [%- IF first_page > 1 -%]
                <li><a href="[% c.uri_for(c.action.name) %]?page_num=1&per_page=[% per_page %]" title="Page 1">1</a></li>
                <li class="disabled"><a href="#">…</a></li>
                [%- END -%]
                [% page = first_page; WHILE page <= last_page -%]
                <li[% IF page == page_num %] class="active"[% END %]><a href="[% c.uri_for(c.action.name) %]?page_num=[% page %]&per_page=[% per_page %]" title="Coucou">[% page %]</a></li>
                [%- page = page + 1 -%]
                [%- END -%]
                [%- IF last_page < pages_count %]
                <li class="disabled"><a href="#">…</a></li>
                <li><a href="[% c.uri_for(c.action.name) %]?page_num=[% pages_count %]&per_page=[% per_page %]" title="Page [% pages_count %]">[% pages_count %]</a></li>
                [% END -%]
                [%- IF page_num < page %]<li><a href="[% c.uri_for(c.action.name) %]?page_num=[% page_num + 1 %]&per_page=[% per_page %]">&rarr;</a></li>[% END %]
              </ul>
            </div>
[%- END %]