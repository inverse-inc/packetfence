$(function () {
    $('#tracker [rel=tooltip]').tooltip({placement: 'bottom'});
/*
    $('.btn-toggle').each(function(index) {
        $(this).hover(
            // In
            function(event) {
                var e = $(this);
                e.text(e.attr('toggle-hover'));
                e.toggleClass('btn-success btn-danger');
            },
            // Out
            function(event) {
                var e = $(this);
                var value = e.text().trim();
                if (value == e.attr('toggle-hover')) {
                    e.text(e.attr('toggle-value-else'));
                    e.toggleClass('btn-success btn-danger');
                }
            }
        );
        $(this).click(function(event) {
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
        });
    });
*/
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
});

function resetAlert(parent) {
    parent.children('.alert').slideUp('fast', function() { $(this).remove(); });
    //parent.children('.alert').each(function(event) { $(this).remove(); });
}

function showSuccess(sibling, msg) {
    var alert = $('.alert-success').first().clone();
    alert.find('span').first().text(msg);
    sibling.before(alert);
    alert.fadeIn('fast').delay(5000).slideUp('fast', function() { $(this).remove(); });
}

function showError(sibling, msg, hidedelay) {
    var alert = $('.alert-error').first().clone();
    alert.find('span').first().text(msg);
    sibling.before(alert);
    if (hidedelay > 0)
        alert.fadeIn('fast').delay(hidedelay).slideUp('fast', function() { $(this).remove(); });
    else
        alert.fadeIn('fast');
}
