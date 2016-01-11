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

        if (window.location.hash.length > 0)
            // User session was expired; preserve URL fragment when defined
            form.find('[name="redirect_url"]').val(window.location.href);

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
                if (location) {
                    if (location == window.location.href)
                        window.location.reload(true);
                    else
                        window.location.href = location;
                } else {
                    window.location.href = "/admin";
                }
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
