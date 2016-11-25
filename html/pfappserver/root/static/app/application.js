$(function () {
    /* Activate toggle buttons */
    $('body').on(
        {'mouseenter': function(event) {
            var btn = $(this);
            btn.text(btn.attr('toggle-hover'));
            btn.toggleClass('btn-success btn-danger');
         },
         'mouseleave': function(event) {
             var btn = $(this);
             var value = $.trim(btn.text());
             if (value == btn.attr('toggle-hover')) {
                 btn.text(btn.attr('toggle-value-else'));
                 btn.toggleClass('btn-success btn-danger');
             }
         },
         'toggle': function(event) {
             var btn = $(this);
             var value = btn.attr('toggle-value');
             btn.fadeOut('fast', function(event) {
                 btn.text(btn.attr('toggle-value-else'));
                 if (btn.hasClass('btn-danger'))
                     btn.removeClass('btn-danger');
             }).fadeIn('fast');
             btn.attr('toggle-value', btn.attr('toggle-value-else'));
             btn.attr('toggle-value-else', value);
             value = btn.attr('toggle-hover');
             btn.attr('toggle-hover', btn.attr('toggle-hover-else'));
             btn.attr('toggle-hover-else', value);
             value = btn.attr('toggle-href');
             btn.attr('toggle-href', btn.attr('href'));
             btn.attr('href', value);
         }},
        '.btn-toggle');

    /* Activate button dropdowns */
    $('.dropdown-toggle').dropdown();

    /* Activate button groups */
    $('body').on('click', '.btn-group .btn', function(event) {
        var btn = $(this);
        var name = btn.attr('name');
        var input = btn.siblings('input[name="' + name + '"]');
        input.val(btn.attr('value'));
        input.trigger('change');
    });

    /* Don't hide special "form" dropdown menu */
    $('body').on('click', '.dropdown-menu-form', function(event) {
        event.stopPropagation();
    });

    /* Live validation for required fields */
    $('body').on('blur', 'input[data-required]', function() {
        isFormInputEmpty($(this));
    });
    $('body').on('changeDate', 'input.datepicker[data-required]', function() {
        isFormInputEmpty($(this));
    });

    /* Live validation for number fields */
    $('body').on('blur', 'input[type="number"]', function() {
        var input = $(this);
        var min = input.attr('min');
        var max = input.attr('max');
        if ($.trim(input.val()).length > 0)
            isInvalidNumber(input, min, max);
    });
});

function getStatusMsg(jqXHR) {
    var status_msg;
    try {
        var obj = $.parseJSON(jqXHR.responseText);
        status_msg = obj.status_msg;
    }
    catch(e) {}
    if (!status_msg) status_msg = _("Cannot Load Content");
    return status_msg;
}

function resetAlert(parent) {
    parent.children('.alert').clearQueue().remove();
    parent.children('.error').removeClass('error');
}


function showAlert(type, sibling, msg, permanent, time) {
    if (typeof time == "undefined") {
        time = 5000;
    }
    var alert = $(type).first().clone();
    alert.find('span').first().text(msg);
    sibling.before(alert);
    if (permanent)
        alert.fadeIn('fast');
    else
        alert.fadeIn('fast').delay(time).slideUp('fast', function() { $(this).remove(); });
}

function showWarning(sibling, msg, permanent, time) {
    showAlert('.alert-block', sibling, msg, permanent, time);
}

function showPermanentWarning(sibling, msg) {
    showWarning(sibling, msg, true);
}

function showSuccess(sibling, msg, permanent, time) {
    showAlert('.alert-success', sibling, msg, permanent, time);
}

function showPermanentSuccess(sibling, msg) {
    showSuccess(sibling, msg, true);
}

function showError(sibling, msg, permanent, time) {
    if (typeof time == "undefined") {
        time = 10000;
    }
    if (typeof msg == 'string') {
        showAlert('.alert-error', sibling, msg, permanent , time);
    }
    else {
        var form = sibling.closest('form');
        $.each(msg, function(name, error) {
            var input = form.find('[name="' + name + '"]');
            var control = input.closest('.control-group');
            control.addClass('error');
            showTab(control, input);
            showAlert('.alert-error', sibling, error, permanent, time);
        });
    }
}

function showPermanentError(sibling, msg) {
    showError(sibling, msg, true);
}

function btnError(btn) {
    btn.fadeOut('fast', function(event) {
        $(this).addClass('btn-danger');
    }).fadeIn('fast').delay(5000).queue(function(event) {
        $(this).removeClass('btn-danger');
        $(this).dequeue();
    });
}

function isFormInputEmpty(input) {
    var control = input.closest('.control-group');
    var empty = false;
    var value;

    if (input.attr('data-toggle') == 'buttons-radio')
        value = input.find('.active').length == 0? null : 1;
    else
        value = input.val();

    if (value == null
        || typeof value == 'string' && $.trim(value).length == 0
        || value.length == 0) {
        control.addClass('error');
        empty = true;

        // If input is in a tab, show the tab
        showTab(control, input);
    }
    else {
        control.removeClass('error');
    }

    return empty;
}

function isInvalidNumber(input, min, max) {
    var control = input.closest('.control-group');
    var isInvalid = false;

    if (/^[0-9]+$/.test($.trim(input.val()))) {
        var value = parseInt(input.val());
        if (typeof min != "undefined" && value < min ||
            typeof max != "undefined" && value > max)
            isInvalid = true;
    }
    else {
        isInvalid = true;
    }
    if (isInvalid) {
        control.addClass('error');
        showTab(control, input);
    }
    else {
        control.removeClass('error');
    }

    return isInvalid;
}

function isFormValid(form) {
    var valid = true;
    form.find('input[data-required]:not(:disabled), input[type="number"]:not(:disabled)').each(function() {
        var input = $(this);
        var control = input.closest('.control-group');
        input.trigger('blur');
        valid = !control.hasClass('error');

        return valid;
    });
    return valid;
}

function showTab(control, input) {
    var tab = control.closest('.tab-pane');
    if (tab) {
        var a = tab.closest('form').find('.nav-tabs a[href="#' + tab.attr('id') + '"]');
        a.tab('show');
        // Scroll to the input
//        var container = tab.closest('.modal-body');
//        if (!container)
//            container = $("body,html");
//        container.animate({scrollTop: input.position().top}, 'fast');
    }
}

/* Translate a string using the general "labels" array defined in the wrapper.tt template */
function _(key) {
    var value = key;
    if (labels[key]) {
        value = labels[key];
    }

    return value;
}

String.prototype.asCSSIdentifier = function() {
    return this.replace(/[^_a-zA-Z0-9]/g, '_');
};
