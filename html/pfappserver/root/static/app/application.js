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
    parent.children('.alert').hide('fast', function() { $(this).remove(); }); //slideUp('fast', function() { $(this).remove(); });
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
        if (value < min || value > max)
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

function switchIsOn(input) {
    var onoffswitch = input.closest('.onoffswitch').find('.onoffswitch-switch');
    var cssRight = parseInt(onoffswitch.css('right'));

    return cssRight == 0;
}

function showTab(control, input) {
    var tab = control.closest('.tab-pane');
    if (tab) {
        var a = tab.closest('form').find('.nav-tabs a[href="#' + tab.attr('id') + '"]');
        a.tab('show');
        // Scroll to the input
        var container = tab.closest('.modal-body');
        if (!container)
            container = $("body,html");
        container.animate({scrollTop: input.position().top}, 'fast');
    }
}
