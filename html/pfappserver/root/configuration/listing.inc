[%- MACRO header(column, title) BLOCK; 
    params = { by => column, filter => filter };
    IF by == column && direction == 'asc';
      params.direction = 'desc';
    END %]
    <th class="listing_[%section%] [%section%]_[%column%]"> <a href="#[% pagination_path(section, params)  %]">[% title %][% IF by == column %] <i class="icon-chevron-[% IF direction == 'desc' %]down[% ELSE %]up[% END %]"></i>[% END %]</a></th>
[% END -%]
      <div>
        <form id="simpleSearch" method="POST" name="simpleSearch" class="form-inline" action="[% c.uri_for(c.controller().action_for('simple_search')) %]">
            <div class="pull-right">
               <input name="filter" id="simpleString" class="search-query" type="text" placeholder="Search..." value="[%filter | html%]">
               <button class="btn btn-primary"><i class="icon-search icon-white"></i></button>
            </div>
        </form>
        <br/>
      [% INCLUDE 'pagination.inc' section = section  IF items.size > 0 %]
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
              <td class="listing_[%section%] [%section%]_[%field%]">[% item.$field %]</td>
              [%- END -%]
            </tr>
            [%- END -%]
          </tbody>
        </table>
      [% INCLUDE 'pagination.inc' section = section IF items.size > 0 %]
