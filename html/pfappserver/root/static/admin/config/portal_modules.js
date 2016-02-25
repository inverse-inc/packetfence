
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
