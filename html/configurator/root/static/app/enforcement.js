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
    var control = form.children('.control-group');
    if (form.find('input:checked').length == 0) {
        control.addClass('error');
        valid = false;
    }
    else {
        control.removeClass('error');
    }

    if (valid) {
        var data = { enforcements: [] };
        $('input:checkbox:checked[name="enforcement"]').each(function(index) {
            data.enforcements.push($(this).val());
        });
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: {json: $.toJSON(data)}
        }).done(function(data) {
            window.location.href = href;
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError(form, obj.status_msg);
        });
    }
    else {
        resetAlert(form.parent());
        showError(form, 'You must choose at least one enforcement mechanism.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }
}