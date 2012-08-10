function init() {
    /* Perform authentication using AJAX */
    $('form[name="login"]').submit(function(event) {
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
                data: { 'username': username.val(), 'password': password.val() }
            }).done(function(data) {
                window.location.href = form.find('[name="redirect_url"]').val();
            }).fail(function(jqXHR) {
                btn.button('reset');
                var obj = $.parseJSON(jqXHR.responseText);
                resetAlert(form);
                showError(form_control, obj.status_msg);
            });
        }
            
        return false;
    });
}