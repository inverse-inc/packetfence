function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function initStep() {
    $('#createUser').click(function(event) {
        var btn = $(this),
        admin_user = $('#admin_user'),
        admin_user_control = admin_user.closest('.control-group'),
        admin_password = $('#admin_password'),
        admin_password_control = admin_password.closest('.control-group'),
        admin_password2 = $('#admin_password2'),
        admin_password2_control = admin_password2.closest('.control-group'),
        valid = true;

        if (btn.hasClass('disabled')) return false;

        if (isFormInputEmpty(admin_user) ||
            isFormInputEmpty(admin_password))
            valid = false;
        else {
            if (admin_password.val() != admin_password2.val()) {
                admin_password_control.addClass('error');
                admin_password2_control.addClass('error');
                valid = false;
            }
            else {
                admin_password_control.removeClass('error');
                admin_password2_control.removeClass('error');
            }
        }
        if (valid) {
            $.ajax({
                type: 'POST',
                url: btn.attr('href'),
                data: { admin_user: admin_user.val(), admin_password: admin_password.val() }
            }).done(function(data) {
                btn.addClass('disabled');
                admin_user.add(admin_password).add(admin_password2).attr('disabled', '');
                resetAlert(admin_user_control.closest('form'));
                showSuccess(admin_user_control, data.status_msg);
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(admin_user_control, obj.status_msg);
            });
        }

        return false;
    });
}

function saveStep(href) {
    var createUser = $('#createUser');

    if (createUser.hasClass('disabled')) {
        window.location.href = href;
    }
    else {
        var form = $('form[name="admin"]');
        btnError(createUser);
        resetAlert(form.parent());
        showError(form, 'Please verify your configuration.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }

    return false;
}