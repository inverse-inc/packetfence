function registerExists() {
    $('#tracker a, .form-actions a').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function initStep() {
    $('#testDatabase').click(function(event) {
        var root_user = $('#root_user'),
        root_user_control = root_user.closest('.control-group'),
        password = $('#root_password'),
        password_control = password.closest('.control-group'),
        valid = true;

        if (root_user.val().trim().length == 0) {
            root_user_control.addClass('error');
            valid = false;
        }
        else {
            root_user_control.removeClass('error');
        }
//        if (password.val().trim().length == 0) {
//            password_control.addClass('error');
//            valid = false;
//        }
//        else {
//            password_control.removeClass('error');
//        }

        if (valid) {
            $.ajax({
                type: 'POST',
                url: $(this).attr('href'),
                data: { root_user: root_user.val(), root_password: password.val() }
            }).done(function(data) {
                resetAlert(root_user.closest('form'));
                showSuccess(root_user.closest('.control-group'), data.status_msg);
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(root_user.closest('.control-group'), obj.status_msg);
            });
        }

        return false;
    });

    $('#createDatabase').click(function(event) {
        var btn = $(this),
        root_user = $('#root_user'),
        root_password = $('#root_password'),
        database = $('#database'),
        database_control = database.closest('.control-group'),
        url = [btn.attr('href'), database.val()],
        valid = true;

        if (btn.hasClass('disabled')) return false;

        if (database.val().trim().length == 0) {
            database_control.addClass('error');
            valid = false;
        }
        else {
            database_control.removeClass('error');
        }

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url.join('/'),
                data: { root_user: root_user.val(), root_password: root_password.val() }
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
        root_user_control = root_user.closest('.control-group'),
        root_password = $('#root_password'),
        database = $('#database'),
        pf_user = $('#pf_user'),
        pf_user_control = pf_user.closest('.control-group'),
        pf_password = $('#pf_password'),
        pf_password2 = $('#pf_password2'),
        url = [btn.attr('href'), database.val()],
        valid = true;

        if (btn.hasClass('disabled')) return false;

        if (root_user.val().trim().length == 0) {
            root_user_control.addClass('error');
            valid = false;
        }
        else {
            root_user_control.removeClass('error');
        }

        if (pf_user.val().trim().length == 0 || pf_password.val() != pf_password2.val()) {
            pf_user_control.addClass('error');
            valid = false;
        }
        else {
            pf_user_control.removeClass('error');
        }

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url.join('/'),
                data: { root_user: root_user.val(), root_password: root_password.val(),
                        pf_user: pf_user.val(), pf_password: pf_password.val() }
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
    var createDatabase = $('#createDatabase'),
    assignUser = $('#assignUser'),
    valid = true;

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
            type: 'POST',
            url: window.location.pathname,
            data: {root_user: $('#root_user').val(),
                   pf_user: $('#pf_user').val(), 
                   database: $('#database').val()}
        }).done(function(data) {
            window.location.href = href;
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('form'), obj.status_msg);
            $("body").animate({scrollTop:0}, 'fast');
        });
    }

    return false;
}

//function formSuccess(input, msg) {
//    input.closest('.control-group').addClass('success');
//    if (msg) {
//        input.nextAll().last().after('<span class="help-inline">' + msg + '</span>');
//    }
//}

//function formError(input, msg) {
//    input.closest('.control-group').addClass('error');
//}