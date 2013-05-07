[% IF page_num -%]
    [% params = { by => by, direction => direction, filter => filter, per_page => per_page } %]
    <div name="section" class="pagination pagination-right">
      <ul>
        [%-
        IF page_num > 1;
            params.page_num = page_num - 1;
        ELSE;
            params.page_num = 1;
        END
        -%]
      <li [%IF page_num == 1 %] class="disabled" [%END%]  ><a href="#[% pagination_path(section, params) %]">&larr;</a></li>
      [%- first_page = page_num - 3;
          IF first_page < 1; first_page = 1; END;
          last_page = first_page + 6;
          IF last_page > pages_count;
            last_page = pages_count;
            first_page = last_page - 6;
            IF first_page < 1; first_page = 1; END;
          END -%]
      [%- IF first_page > 1 -%]
        [% params.page_num = 1 -%]
        <li><a href="#[% pagination_path(section, params) %]" title="Page 1">1</a></li>
        <li class="disabled"><a href="#">&hellip;</a></li>
      [%- END -%]
      [% page = first_page; WHILE page <= last_page -%]
        [% params.page_num = page %]
        <li[% IF page == page_num %] class="disabled" [% END %] ><a href="#[% pagination_path(section, params) %]" title="Page [%page%]">[% page %]</a></li>
        [%- page = page + 1 -%]
      [%- END -%]
      [%- IF last_page < pages_count -%]
        [% params.page_num = pages_count %]
        <li class="disabled"><a href="#">&hellip;</a></li>
        <li><a href="#[% pagination_path(section, params) %]" title="Page [% pages_count %]">[% pages_count %]</a></li>
      [%- END -%]
      [%- IF page_num < page - 1 -%]
        [% params.page_num = page_num + 1 %]
      [%- END %]
        <li class="[%- IF page_num == last_page -%]disabled[%-END -%]"  ><a href="#[% pagination_path(section, params) %]">&rarr;</a></li>
      </ul>
    </div>
[%- END %]
