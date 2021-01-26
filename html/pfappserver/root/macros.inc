[%- MACRO l(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n(text, args) BLOCK;c.localize(text, args) | none ;END -%]

[%- MACRO i18n_format(text, args) BLOCK;c.localize(text, args) | none;END -%]

[%- MACRO doc(section, guide) BLOCK -%]
[%- UNLESS guide; guide = 'Installation_Guide'; END -%]
[% c.generate_doc_link(section, guide) | none %]
[%- END -%]

[%- MACRO doc_url(section, guide) BLOCK -%]
[%- UNLESS guide; guide = 'Installation_Guide'; END -%]
[% c.generate_doc_url(section, guide) | none %]
[%- END -%]

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

[%- MACRO element_attributes(attributes) BLOCK -%]
[%- FOREACH key IN attributes.keys -%]
 [% key %] = "[% attributes.$key %]"
[%- END -%]
[%- END -%]

[%- MACRO pagination(action, pageNumber, pageCount, query, from_form, captures, pagination_attributes)  BLOCK -%]
[%
# Number of pages to show before and after the middle page in the list
    pageWrap = 3;
    pageWrapTotal = pageWrap * 2;
    IF pageCount <= 0;
        pageCount = 1;
    END;
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
    add_captures = [];
    IF captures.defined;
        CALL add_captures.import(captures);
    END;
    params = {};
    CALL params.import(query);
%]
<div class="pagination pagination-right" [%IF from_form %] data-from-form="[% from_form %]" [% END %]  [% IF pagination_attributes %] [% element_attributes(pagination_attributes) | none %] [% END %] >
  <ul>
    [% IF pageNumber == 1 %]
    <li class="disabled"><span>&larr;</span></li>
    [% ELSE %]
    [% params.page_num = pageNumber - 1 %]
    <li><a href="[% c.uri_for(action, add_captures, params) %]">&larr;</a></li>
    [% END %]
    [%- IF firstPage > 1 -%]
      [% params.page_num = 1 %]
      <li><a href="[% c.uri_for(action, add_captures, params) %]" title="Page 1">1</a></li>
      <li class="disabled"><span>&hellip;</span></li>
    [%- END -%]
    [% currentPage = firstPage %]
    [% WHILE currentPage <= lastPage %]
      [% params.page_num = currentPage %]
      [%IF currentPage == pageNumber %]
        <li class="disabled"><a href="[% c.uri_for(action, add_captures, params) %]">[%currentPage%]</a></li>
      [% ELSE  %]
        <li><a href="[% c.uri_for(action, add_captures, params) %]">[%currentPage%]</a></li>
      [%END%]
    [%currentPage = currentPage + 1%]
    [% END %]
    [%- IF lastPage < pageCount -%]
      [% params.page_num = pageCount %]
      <li class="disabled"><span>&hellip;</span></li>
      <li><a href="[% c.uri_for(action, add_captures, params)  %]" title="Page [% pageCount %]">[% pageCount %]</a></li>
    [%- END -%]
    [% IF pageNumber == lastPage %]
    <li class="disabled"><span>&rarr;</span></li>
    [% ELSE %]
      [% params.page_num = pageNumber + 1 %]
    <li><a href="[% c.uri_for(action, add_captures, params) %]">&rarr;</a></li>
    [% END %]
  </ul>
</div>
[%- END -%]
