"use strict";

/*
 * The Users class defines the operations available from the controller.
 */
var Users = function() {
};

Users.prototype.get = function(options) {
    $.ajax({
        url: options.url
    })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Users.prototype.post = function(options) {
    $.ajax({
        url: options.url,
        type: 'POST',
        data: options.data
    })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Users.prototype.toggleViolation = function(options) {
    var action = options.status? "open" : "close";
    var url = ['/node',
               action,
               options.name.substr(10)];
    $.ajax({ url: url.join('/') })
        .always(options.always)
        .done(options.success)
        .fail(options.error);
};

/*
 * The UserView class defines the DOM operations from the Web interface.
 */
var UserView = function(options) {
    this.users = options.users;
    this.disableToggleViolation = false;

    var read = $.proxy(this.readUser, this);
    options.parent.on('click', '[href*="user"][href$="/read"]', read);

    this.proxyFor($('body'), 'submit', 'form[name="users"]', this.createUser);

    this.proxyFor($('body'), 'submit', '#modalUser form[name="modalUser"]', this.updateUser);

    this.proxyClick($('body'), '#modalUser [href$="/delete"]', this.deleteUser);

    this.proxyClick($('body'), '#modalUser #resetPassword', this.resetPassword);

    this.proxyClick($('body'), '#modalUser #mailPassword', this.mailPassword);

    this.proxyFor($('body'), 'show', 'a[data-toggle="tab"][href="#userViolations"]', this.updateTab);

    this.proxyFor($('body'), 'show', 'a[data-toggle="tab"][href="#userDevices"]', this.updateTab);

    this.proxyClick($('body'), '#modalUser [href$="/read"]', this.readNode);

    this.proxyFor($('body'), 'switch-change', '#modalUser .switch', this.toggleViolation);

    /* Update the advanced search form to the next page or resort the query */
    this.proxyClick($('body'), '[href*="#user/advanced_search"]', this.advancedSearchUpdater);

    this.proxyClick($('body'), '#modalPasswords a[href$="mail"]', this.mailPasswordFromForm);

    this.proxyClick($('body'), '#modalPasswords a[href$="print"]', this.printPasswordFromForm);

    this.proxyClick($('body'), '#user_bulk_actions .bulk_action', this.submitItems);

    $('body').on('change', '#ruleActions select[name$=type]', function(event) {
        /* Update the rule action fields when changing an action type */
        updateAction($(this));
    });

    $('body').on('admin.added', '#ruleActions tr', function(event) {
        /* Update the rule action fields when adding an action */
        var tr = $(this);
        tr.find(':input').removeAttr('disabled');
        var type = tr.find('select[name$=type]').first();
        updateAction(type);
    });

    $('body').on('section.loaded', '#section', function(e) {
        /* Initialize the action field */
        $('#ruleActions tr:not(.hidden) select[name$=type]').each(function() {
            updateAction($(this));
        });
        /* Disable checked columns from import tab since they are required */
        $('form[name="users"] .columns :checked').attr('disabled', 'disabled');
    });
};

UserView.prototype.proxyFor = function(obj, action, target, method) {
    obj.on(action, target, $.proxy(method, this));
};

UserView.prototype.proxyClick = function(obj, target, method) {
    this.proxyFor(obj, 'click', target, method);
};

UserView.prototype.readUser = function(e) {
    e.preventDefault();

    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    this.users.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            $('#modalUser').remove();
            $('body').append(data);
            var modal = $("#modalUser");
            modal.find('.datepicker').datepicker({ autoclose: true });
            modal.find('#ruleActions tr:not(.hidden) select[name$=type]').each(function() {
                updateAction($(this), true);
            });
            modal.on('shown', function() {
                modal.find(':input:visible').first().focus();
                modal.find('[data-toggle="tooltip"]').tooltip({placement: 'top'});
            });
            modal.modal({ show: true });
        },
        errorSibling: section.find('h2').first()
    });
};

UserView.prototype.createUser = function(e) {
    var form = $(e.target),
    btn = form.find('[type="submit"]').first(),
    href = $('#section .nav-tabs .active a').attr('href'),
    pos = href.lastIndexOf('#'),
    disabled_inputs = form.find('.hidden :input, .tab-pane:not(.active) :input'),
    valid;

    // Don't submit inputs from hidden rows and tabs.
    // The functions isFormValid and serialize will ignore disabled inputs.
    disabled_inputs.attr('disabled', 'disabled');

    // Identify the type of creation (single, multiple or import) from the selected tab
    form.find('input[name="type"]').val(href.substr(++pos));
    valid = isFormValid(form);

    if (valid) {
        btn.button('loading');
        resetAlert($('#section'));

        // Since we can be uploading a file, the form target is an iframe from which
        // we read the JSON returned by the server.
        var iform = $("#iframe_form");
        iform.one('load', function(event) {
            // Restore disabled inputs
            disabled_inputs.removeAttr('disabled');

            $("body,html").animate({scrollTop:0}, 'fast');
            btn.button('reset');
            var body = $(this).contents().find('body');
            if (body.find('form').length) {
                // We received a HTML form
                var modal = $('#modalPasswords');
                modal.empty();
                modal.append(body.children());
                modal.modal({ backdrop: 'static', shown: true });
            }
            else {
                // We received JSON
                var data = $.parseJSON(body.text());
                if (data.status < 300)
                    showPermanentSuccess(form, data.status_msg);
                else
                    showPermanentError(form, data.status_msg);
            }
        });
    }
    else {
        // Restore disabled inputs
        disabled_inputs.removeAttr('disabled');
    }

    return valid;
};

UserView.prototype.updateUser = function(e) {
    e.preventDefault();

    var modal = $('#modalUser');
    var form = modal.find('form').first();
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);

        this.users.post({
            url: form.attr('action'),
            data: form.serialize(),
            success: function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            },
            errorSibling: modal_body.children().first()
        });
    }
};

UserView.prototype.deleteUser = function(e) {
    e.preventDefault();

    var modal = $('#modalUser');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var url = btn.attr('href');
    this.users.get({
        url: url,
        success: function(data) {
            modal.modal('hide');
            modal.on('hidden', function() {
                $(window).hashchange();
            });
        },
        errorSibling: modal_body.children().first()
    });
};

UserView.prototype.resetPassword = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var url = btn.attr('href');
    var password = $('#password');
    var password_control = password.closest('.control-group');
    var password2 = $('#password2');
    var password2_control = password2.closest('.control-group');
    var sibbling = $('#userPassword').children().first();
    var valid = true;

    if (isFormInputEmpty(password) || isFormInputEmpty(password2))
        valid = false;
    else {
        if (password.val() != password2.val()) {
            password_control.addClass('error');
            password2_control.addClass('error');
            valid = false;
        }
        else {
            password_control.removeClass('error');
            password2_control.removeClass('error');
        }
    }
    if (valid) {
        this.users.post({
            url: url,
            data: { password: password.val() },
            success: function(data) {
                showSuccess(password_control, data.status_msg);
                $('#reminder').removeClass('hidden');
            },
            errorSibling: password_control
        });
    }
};

/* See root/user/view.tt */
UserView.prototype.mailPassword = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var url = btn.attr('href'); // pid is in the URL
    var modal_body = btn.closest('.modal').find('.modal-body');
    var control = $('#userPassword .control-group').first();

    btn.button('loading');
    this.users.get({
        url: url,
        always: function() {
            btn.button('reset');
            resetAlert(modal_body);
        },
        success: function(data) {
            showSuccess(control, data.status_msg);
        },
        errorSibling: control
    });
};

/* See root/user/list_password.tt */
UserView.prototype.mailPasswordFromForm = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var url = btn.attr('href');
    var form = btn.closest('form'); // pids are specified in the form
    var modal_body = form.closest('.modal').find('.modal-body');

    btn.button('loading');
    this.users.post({
        url: url,
        data: form.serialize(),
        always: function() {
            $("body,html").animate({scrollTop:0}, 'fast');
            btn.button('reset');
            resetAlert(modal_body);
        },
        success: function(data) {
            showSuccess(modal_body.children().first(), data.status_msg);
        },
        errorSibling: modal_body.children().first()
    });
};

/* See root/user/list_password.tt */
UserView.prototype.printPasswordFromForm = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var form = btn.closest('form'); // pids are specified in the form
    form.attr('action', btn.attr('href'));
    form.attr('target', '_blank'); // open a new page
    form.submit();
};

UserView.prototype.updateTab = function(e) {
    var btn = $(e.target);
    var target = $(btn.attr("href"));
    target.load(btn.attr("data-href"), function() {
        target.find('.switch').bootstrapSwitch();
    });
    return true;
};

UserView.prototype.readNode = function(e) {
    e.preventDefault();

    var url = $(e.target).attr('href');
    var section = $('#section');
    var loader = section.prev('.loader');
    var modalUser = $("#modalUser");
    var modalUser_body = modalUser.find('.modal-body').first();
    loader.show();
    section.fadeTo('fast', 0.5);
    this.users.get({
        url: url,
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            $('body').append(data);
            var modalNode = $("#modalNode");
            modalUser.one('hidden', function(e){
                modalNode.modal('show');
            });
            modalNode.one('hidden', function (e) {
                modalUser.modal('show');
            });
            modalUser.modal('hide');
        },
        errorSibling: modalUser_body.children().first()
    });
};

UserView.prototype.toggleViolation = function(e) {
    e.preventDefault();

    // Ignore event if it occurs while processing a toggling
    if (this.disableToggleViolation) return;
    this.disableToggleViolation = true;

    var that = this;
    var btn = $(e.target);
    var name = btn.find('input:checkbox').attr('name');
    var status = btn.bootstrapSwitch('status');
    var pane = $('#userViolations');
    resetAlert(pane.parent());
    this.users.toggleViolation({
        name: name,
        status: status,
        success: function(data) {
            showSuccess(pane.children().first(), data.status_msg);
            that.disableToggleViolation = false;
        },
        error: function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(pane.children().first(), status_msg);
            // Restore switch state
            btn.bootstrapSwitch('setState', !status, true);
            that.disableToggleViolation = false;
        }
    });
};

UserView.prototype.advancedSearchUpdater = function(e) {
    e.preventDefault();
    var link = $(e.currentTarget);
    var form = $('#advancedSearch');
    var href = link.attr("href");
    if(href) {
        href = href.replace(/^.*#user\/advanced_search\//,'');
        var values = href.split("/");
        for(var i =0;i<values.length;i+=2) {
            var name = values[i];
            var value = values[i + 1];
            form.find('[name="' + name + '"]:not(:disabled)').val(value);
        }
        form.submit();
    }
    return false;
};

UserView.prototype.submitItems = function(e) {
    var target = $(e.currentTarget);
    var section = $('#section');
    var status_container = $("#section").find('h2').first();
    var items = $("#items").serialize();
    var users = this.users;
    if (items.length) {
        if (section) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var loader = section.prev('.loader');
            loader.show();
            section.fadeTo('fast', 0.5, function() {
                users.post({
                    url: target.attr("data-target"),
                    data: items,
                    success: function(data) {
                        $("#section").one('section.loaded', function() {
                            showSuccess($("#section").find('h2').first(), data.status_msg);
                        });
                        $(window).hashchange();
                    },
                    always: function(data) {
                        loader.hide();
                        section.fadeTo('fast', 1.0);
                    },
                    errorSibling: status_container
                });
            });
        }
    }
};
