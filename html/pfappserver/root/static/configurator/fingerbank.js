function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        window.location.href = href;
        return false; // don't follow link
    });
}

function initStep() {
  $('#configure_fingerbank_api_key').click(function(e) {
    e.preventDefault();
    var btn = $(e.target);
    
    $.ajax({
        headers: {
          'Accept':'application/json',
        },
        type: 'POST',
        url: btn.attr('href'),
        data: { api_key: $('#api_key').val() }
    }).done(function(data) {
        btn.addClass('disabled');
        $('#api_key').attr('disabled', '');
        resetAlert(btn.closest('.control-group'));
        showSuccess(btn.closest('.control-group'), data.status_msg);
    }).fail(function(jqXHR) {
        var obj = $.parseJSON(jqXHR.responseText);
        showError(btn.closest('.control-group'), obj.status_msg);
    });

    return false;
  });
  $('#configure_fingerbank_mysql').click(function(e) {
    e.preventDefault();
    var btn = $(e.target);
    
    $.ajax({
        type: 'GET',
        url: btn.attr('href'),
    }).done(function(data) {
        btn.addClass('disabled');
        resetAlert(btn.closest('.control-group'));
        showSuccess(btn.closest('.control-group'), data.status_msg);
    }).fail(function(jqXHR) {
        var obj = $.parseJSON(jqXHR.responseText);
        showError(btn.closest('.control-group'), obj.status_msg);
    });

    return false;
  });
}

