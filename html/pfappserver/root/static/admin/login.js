function init() {
    /* Perform authentication using AJAX */
    $('form[name="login"]').submit(function(event) {
        event.stopPropagation();
        var form = $(this),
        form_control = form.children('.control-group').first(),
        btn = form.find('[type="submit"]'),
        username = form.find('#username'),
        password = form.find('#password'),
        action = $(this).attr('action'),
        valid = true;

        if (isFormInputEmpty(username) ||
            isFormInputEmpty(password))
            valid = false;

        if (valid) {
            btn.button('loading');
            $.ajax({
                type: 'POST',
                url: action,
                data: form.serialize()
            }).done(function(data) {
                var location = data.success;
                if (location)
                    window.location.href = location;
            }).fail(function(jqXHR) {
                btn.button('reset');
                var obj = $.parseJSON(jqXHR.responseText);
                resetAlert(form.parent());
                showError(form_control, obj.status_msg);
            });
        }
            
        return false;
    });

    $('#username').focus();
}