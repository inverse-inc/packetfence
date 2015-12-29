[%- MACRO l(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n_format(text, args) BLOCK;c.localize(text, args) | none;END -%]

[%- MACRO pagination_path(section, params)  BLOCK -%]
    [%- tags =  [ 'page_num'  'by'  'direction'  'per_page'  'filter'] -%]
    [%- "${section}" -%]
    [%- FOREACH key IN params.keys  -%]
        [%- IF params.$key -%]
            [%- path_part = params.$key | uri -%]
            [%- "/${key}/${path_part}" -%]
        [%- END  -%]
    [%- END -%]
[%- END -%]

[%- MACRO pagination(action, pageNumber, pageCount, query, from_form)  BLOCK -%]
[%
# Number of pages to show before and after the middle page in the list
    pageWrap = 3;
    pageWrapTotal = pageWrap * 2;
# Calculate the first of the list
    firstPage = pageNumber - pageWrap;
    #Take care of wrap around
    IF firstPage < 1; firstPage = 1; END;
# Calculate the last page
    lastPage = firstPage + pageWrapTotal;
    #Take care of wrap around
    IF lastPage > pageCount;
        lastPage = pageCount;
        firstPage = lastPage - pageWrapTotal;
        IF firstPage < 1; firstPage = 1; END;
    END;
%]
<div class="pagination pagination-right" [%IF from_form %] data-from-form="[% from_form %]" [% END %]>
  <ul>
    [% IF pageNumber == 1 %]
    <li class="disabled"><a>&larr;</a></li>
    [% ELSE %]
    <li><a href="[% c.uri_for(action, pageNumber - 1, query) %]">&larr;</a></li>
    [% END %]
    [%- IF firstPage > 1 -%]
      <li><a href="[% c.uri_for(action, 1, query) %]" title="Page 1">1</a></li>
      <li class="disabled"><a href="#">&hellip;</a></li>
    [%- END -%]
    [% currentPage = firstPage %]
    [% WHILE currentPage <= lastPage %]
      [%IF currentPage == pageNumber %]
        <li class="disabled"><a href="[% c.uri_for(action, currentPage, query) %]">[%currentPage%]</a></li>
      [% ELSE  %]
        <li><a href="[% c.uri_for(action, currentPage, query) %]">[%currentPage%]</a></li>
      [%END%]
    [%currentPage = currentPage + 1%]
    [% END %]
    [%- IF lastPage < pageCount -%]
      <li class="disabled"><a href="#">&hellip;</a></li>
      <li><a href="[% c.uri_for(action, pageCount, query)  %]" title="Page [% pageCount %]">[% pageCount %]</a></li>
    [%- END -%]
    [% IF pageNumber == lastPage %]
    <li class="disabled"><a >&rarr;</a></li>
    [% ELSE %]
    <li><a href="[% c.uri_for(action, pageNumber + 1, query) %]">&rarr;</a></li>
    [% END %]
  </ul>
</div>
[%- END -%]
