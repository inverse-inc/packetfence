
$('#section').on('click', '[id$="Empty"]', function(event) {
  event.preventDefault();
  var match = /(.+)Empty/.exec($(event.target).closest('.unwell').attr('id'));
  var id = match[1];
  var emptyId = match[0];
  $('#'+id).trigger('addrow');
  $('#'+emptyId).addClass('hidden');
  return false;
});

$('#section').on('submit', 'form[name="formItem"]', function(e) {
  e.preventDefault();

  var form = $(this),
  btn = form.find('.btn-primary'),
  valid = isFormValid(form);

  $('select[name$=".type"]:not(:disabled)').each(function(i,e){
    if($(e).val() == "Select an option"){
      valid = false;
      showPermanentError(form, "Please select a valid action.");
    }
  });

  if (valid) {
    btn.button('loading');
    resetAlert($('#section'));
    $.ajax({
        type: 'POST',
        url: form.attr('action'),
        data: form.serialize()
    }).always(function() {
        btn.button('reset');
    }).done(function(data, textStatus, jqXHR) {
        showSuccess(form, "Saved");
        window.location.hash = "#config/portal_module/"+form.find('input[name="id"]').val()+"/read"
    }).fail(function(jqXHR) {
        $("body,html").animate({scrollTop:0}, 'fast');
        var status_msg = getStatusMsg(jqXHR);
        showPermanentError(form, status_msg);
    });
  }
});

$('#section').on('click', '.delete-portal-module', function(e){
  e.preventDefault();
  var button = $(e.target);
  button.button('loading');
  $.ajax({
        type: 'GET',
        url: button.attr('href'),
    }).always(function() {
    }).done(function(data, textStatus, jqXHR) {
        showSuccess(button.closest('.table'), "Deleted");
        button.closest('tr').remove();
    }).fail(function(jqXHR) {
        button.button('reset');
        $("body,html").animate({scrollTop:0}, 'fast');
        var status_msg = getStatusMsg(jqXHR);
        showPermanentError(button.closest('.table'), status_msg);
    });
  return false; 
});

$('#section').on('click', '.expand', function(e){
  e.preventDefault();
  $(e.target).hide(function(){
    $($(e.target).attr('data-expand')).slideDown();
  });
  return false;  
});

$('#section').on('change', '#actions select[name$=".type"]', function(event) {
  var type_input = $(event.currentTarget);
  updateActionMatchInput(type_input,false);
});

$('#section').on('click', '#actionsContainer a[href="#add"]', function(event) {
  setTimeout(initActionMatchInput, 3000);
});

function initActionMatchInput() {
  $('select[name$=".type"]:not(:disabled)').each(function(i,e){
      updateActionMatchInput($(e),true);
  });
}

function updateActionMatchInput(type_input, keep) {
    var match_input = type_input.next();
    var type_value = type_input.val();
    var match_input_template_id = '#' + type_value + "_action_match";
    var match_input_template = $(match_input_template_id);
    if ( match_input_template.length == 0 ) {
        match_input_template = $('#default_action_match');
    }
    if ( match_input_template.length ) {
        changeInputFromTemplate(match_input, match_input_template, keep);
        if (type_value == "switch") {
            type_input.next().typeahead({
                source: searchSwitchesGenerator($('#section h2')),
                minLength: 2,
                items: 11,
                matcher: function(item) { return true; }
            });
        }
    }
}

