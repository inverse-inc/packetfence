
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
  var button;
  $.ajax({
        type: 'GET',
        url: button.attr('action'),
    }).always(function() {
        btn.button('reset');
    }).done(function(data, textStatus, jqXHR) {
        window.location.reload();
    }).fail(function(jqXHR) {
        $("body,html").animate({scrollTop:0}, 'fast');
        var status_msg = getStatusMsg(jqXHR);
        showPermanentError(button, status_msg);
    });
  return false; 
});
