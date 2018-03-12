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

        var continueBtn = btn.closest('form').find('[type="submit"]');
        continueBtn.removeClass("btn-danger").addClass("btn-primary").html(continueBtn.data("msg-done"));
    }).fail(function(jqXHR) {
        var obj = $.parseJSON(jqXHR.responseText);
        showError(btn.closest('.control-group'), obj.status_msg);
    });

    return false;
  });
}

