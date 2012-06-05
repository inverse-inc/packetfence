$(function () {
    /* Register tracker tooltips */
    $('#tracker [rel=tooltip]').tooltip({placement: 'bottom'});

    /* Activate toggle buttons */
    $('tbody').on(
        {'mouseenter': function(event) {
            var e = $(this);
            e.text(e.attr('toggle-hover'));
            e.toggleClass('btn-success btn-danger');
         },
         'mouseleave': function(event) {
             var e = $(this);
             var value = e.text().trim();
             if (value == e.attr('toggle-hover')) {
                 e.text(e.attr('toggle-value-else'));
                 e.toggleClass('btn-success btn-danger');
             }
         },
         'click': function(event) {
            var e = $(this);
            var value = e.attr('toggle-value');
            e.fadeOut('fast', function(event) {
                e.text(e.attr('toggle-value-else'));
                if (e.hasClass('btn-danger'))
                    e.removeClass('btn-danger');
            }).fadeIn('fast');
            e.attr('toggle-value', e.attr('toggle-value-else'));
            e.attr('toggle-value-else', value);
            value = e.attr('toggle-hover');
            e.attr('toggle-hover', e.attr('toggle-hover-else'));
            e.attr('toggle-hover-else', value);
            value = e.attr('toggle-href');
            e.attr('toggle-href', e.attr('href'));
            e.attr('href', value);
            e.trigger('click:toggled');
         }},
        '.btn-toggle');

    if (typeof initModals == 'function') initModals();
    if (typeof initStep == 'function') initStep();
    if (typeof registerExits == 'function') registerExits();
});

function resetAlert(parent) {
    parent.children('.alert').hide(); //slideUp('fast', function() { $(this).remove(); });
}

function showSuccess(sibling, msg) {
    var alert = $('.alert-success').first().clone();
    alert.find('span').first().text(msg);
    sibling.before(alert);
    alert.fadeIn('fast').delay(5000).slideUp('fast', function() { $(this).remove(); });
}

function showError(sibling, msg) {
    var alert = $('.alert-error').first().clone();
    alert.find('span').first().text(msg);
    sibling.before(alert);
    alert.fadeIn('fast').delay(10000).slideUp('fast', function() { $(this).remove(); });
}

function showPermanentError(sibling, msg) {
    var alert = $('.alert-error').first().clone();
    alert.find('span').first().text(msg);
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

    if (input.val().trim().length == 0) {
        control.addClass('error');
        empty = true;
    }
    else {
        control.removeClass('error');
    }

    return empty;
}
