$(function () {
    /* Activate toggle buttons */
    $('tbody').on(
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

    $('.dropdown-toggle').dropdown();
});

function resetAlert(parent) {
    parent.children('.alert').hide(); //slideUp('fast', function() { $(this).remove(); });
}

function showSuccess(sibling, msg) {
    var alert = $('.alert-success').first().clone();
    alert.find('span').first().html(msg);
    sibling.before(alert);
    alert.fadeIn('fast').delay(5000).slideUp('fast', function() { $(this).remove(); });
}

function showError(sibling, msg) {
    var alert = $('.alert-error').first().clone();
    alert.find('span').first().html(msg);
    sibling.before(alert);
    alert.fadeIn('fast').delay(10000).slideUp('fast', function() { $(this).remove(); });
}

function showPermanentError(sibling, msg) {
    var alert = $('.alert-error').first().clone();
    alert.find('span').first().html(msg);
    sibling.before(alert);
    alert.fadeIn('fast');
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

    if ($.trim(input.val()).length == 0) {
        control.addClass('error');
        empty = true;
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
        if (value < min || value > max)
            isInvalid = true;
    }
    else {
        isInvalid = true;
    }
    if (isInvalid) {
        control.addClass('error');
    }
    else {
        control.removeClass('error');
    }

    return isInvalid;
}
