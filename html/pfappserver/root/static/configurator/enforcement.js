/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function saveStep(href) {
    var valid = true;
    var form = $('form[name="enforcement"]');
    if (form.find('input:checked').length == 0) {
        valid = false;
    }

    if (valid) {
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: form.serialize()
        }).done(function(data) {
            window.location.href = href;
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError(form, obj.status_msg);
        });
    }
    else {
        resetAlert(form.parent());
        showError(form.find('table'), 'You must choose at least one enforcement mechanism.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }
}
