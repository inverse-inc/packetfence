function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function initModals() {
    /* Root password reset */
    $('#modalRootPassword .modal-footer a').click(function(event) {
        var modal = $('#modalRootPassword'),
        root_user = modal.find('input[name="root_user"]'),
        root_pass_new = modal.find('input[name="root_pass_new"]'),
        root_pass_new_control = root_pass_new.closest('.control-group'),
        root_pass2_new = modal.find('input[name="root_pass2_new"]'),
        root_pass2_new_control = root_pass2_new.closest('.control-group'),
        valid = true;
        if (isFormInputEmpty(root_user) ||
            isFormInputEmpty(root_pass_new))
            valid = false;
        else {
            if (root_pass_new.val() != root_pass2_new.val()) {
                root_pass_new_control.addClass('error');
                root_pass2_new_control.addClass('error');
                valid = false;
            }
            else {
                root_pass_new_control.removeClass('error');
                root_pass2_new_control.removeClass('error');
            }
        }
        if (valid) {
            var modal_body = modal.find('.modal-body').first();
            resetAlert(modal_body);
            $.ajax({
                type: 'POST',
                url: $(this).attr('href'),
                data: { root_user: root_user.val(), root_password_new: root_pass_new.val() }
            }).done(function(data) {
                modal.modal('toggle');
                showSuccess($('#root_user').closest('.control-group'), data.status_msg);
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(modal_body.children('form').first(), obj.status_msg);
            });
        }

        return false;
    });
}

function initStep() {
    $('#testDatabase').click(function(event) {
        var root_user = $('#root_user'),
        password = $('#root_password'),
        valid = true;

        if (isFormInputEmpty(root_user))
            valid = false;

        if (valid) {
            $.ajax({
                type: 'POST',
                url: $(this).attr('href'),
                data: { root_user: root_user.val(), root_password: password.val() }
            }).done(function(data) {
                resetAlert(root_user.closest('form'));
                showSuccess(root_user.closest('.control-group'), data.status_msg);
            }).fail(function(jqXHR) {
                if (jqXHR.status == 412) {
                    var modal = $('#modalRootPassword');
                    modal.find('input[name="root_user"]').val($('#root_user').val());
                    modal.modal('show');
                }
                else {
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError(root_user.closest('.control-group'), obj.status_msg);
                }
            });
        }

        return false;
    });

    $('#createDatabase').click(function(event) {
        var btn = $(this),
        root_user = $('#root_user'),
        root_password = $('#root_password'),
        database = $('input[name="database.db"]'),
        database_control = database.closest('.control-group'),
        url = [btn.attr('href'), database.val()],
        valid = true;

        if (btn.hasClass('disabled')) return false;

        if (isFormInputEmpty(root_user) ||
            isFormInputEmpty(database))
            valid = false;

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url.join('/'),
                data: { root_user: root_user.val(), root_password: root_password.val() },
                statusCode: {
                    412: function(jqXHR) { alert("code 412!"); }
                }
            }).done(function(data) {
                btn.addClass('disabled');
                database.attr('disabled', '');
                resetAlert(database_control.closest('form'));
                showSuccess(database_control, data.status_msg);
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(database_control, obj.status_msg);
            });
        }

        return false;
    });

    $('#assignUser').click(function(event) {
        var btn = $(this),
        root_user = $('#root_user'),
        root_password = $('#root_password'),
        database = $('input[name="database.db"]'),
        pf_user = $('input[name="database.user"]'),
        pf_user_control = pf_user .closest('.control-group'),
        pf_password = $('input[name="database.pass"]'),
        pf_password_control = pf_password.closest('.control-group'),
        pf_password2 = $('input[name="database.pass2"]'),
        pf_password2_control = pf_password2.closest('.control-group'),
        url = [btn.attr('href'), database.val()],
        valid = true;

        if (btn.hasClass('disabled')) return false;

        if (isFormInputEmpty(root_user) ||
            isFormInputEmpty(pf_user) ||
            isFormInputEmpty(pf_password))
            valid = false;

        if (pf_password.val() != pf_password2.val()) {
            pf_password_control.addClass('error');
            pf_password2_control.addClass('error');
            valid = false;
        }
        else {
            pf_password_control.removeClass('error');
            pf_password2_control.removeClass('error');
        }

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url.join('/'),
                data: { root_user: root_user.val(), root_password: root_password.val(),
                        'database.user': pf_user.val(), 'database.pass': pf_password.val() }
            }).done(function(data) {
                btn.addClass('disabled');
                pf_user.add(pf_password).add(pf_password2).attr('disabled', '');
                resetAlert(pf_user_control.closest('form'));
                showSuccess(pf_user_control, data.status_msg);
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(pf_user_control, obj.status_msg);
            });
        }

        return false;
    });
}

function saveStep(href) {
    var createDatabase = $('#createDatabase');
    var assignUser = $('#assignUser');
    var valid = true;

    if (!createDatabase.hasClass('disabled')) {
        btnError(createDatabase);
        valid = false;
    }
    if (!assignUser.hasClass('disabled')) {
        btnError(assignUser);
        valid = false;
    }

    if (valid) {
       $.ajax({
            type: 'GET',
            url: window.location.pathname
        }).done(function(data) {
            window.location.href = href;
        });
    }
    else {
        var form = $('form[name="database"]');
        resetAlert(form.parent());
        showError(form, 'Please verify your configuration.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }

    return false;
}