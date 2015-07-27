
    <div class="modal fade hide" id="savedSearch">
      <form id="savedSearchForm" class="form-horizontal" method="[% method %]" action="[% c.uri_for(c.controller(savedSearchController).action_for('create'))  %]">

        <div class="modal-header">
          <a class="close" data-dismiss="modal">&times;</a>
          <h3>[% l('Save Search') %]</h3>
        </div>

        <div class="modal-body">
          [% saved_search_form.block('search').render | none %]
        </div>

        <div class="modal-footer">
          <a href="#" class="btn" data-dismiss="modal">[% l('Close') %]</a>
          <button class="btn btn-primary">[% l('Save') %]</button>
        </div>

      </form>
    </div>
