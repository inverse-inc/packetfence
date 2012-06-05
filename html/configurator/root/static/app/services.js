function registerExits() {
    $('.form-actions button').click(function(event) {
        var btn = $(this);
        if (btn.hasClass('disabled')) return false;
        var href = btn.attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function saveStep(href) {

    $('table .badge').each(function(index, event) {
        $(this).fadeIn().delay(100*index).fadeOut('fast', function(event) {
            $(this).text('Starting').removeClass('badge-error badge-success').addClass('badge-warning');
        }).fadeIn('fast');
    });

    $.ajax({
        type: 'POST',
        url: href
    }).done(function(data) {
        resetAlert($('#services'));
        servicesUpdate(data);
    }).fail(function(jqXHR) {
        servicesError();
        var obj = $.parseJSON(jqXHR.responseText);
        showPermanentError($('#services table'), obj.status_msg);
    });

}

function servicesUpdate(data) {

    var startFailed = false;

    for ( var service in data.services ) {
        // identify services that didn't start and set failure flag
        if (data.services[service] == "0") {
            $('#service-' + service).fadeOut('fast', function(event) {
                $(this).text('Stopped').removeClass('badge-success badge-warning').addClass('badge-important');
            }).fadeIn();
            startFailed = true;
        }
        // identify started services
        else {
            $('#service-' + service).fadeOut('fast', function(event) {
                $(this).text('Started').removeClass('badge-error badge-warning').addClass('badge-success');
            }).fadeIn();
        }
    }

    if (!startFailed) {
        // added a delay for dramatic effect
        window.setTimeout(function() { $('#modalRedirection').modal({ show: true }); }, 2000 );
    }
    else {
        $('#serviceErrors pre').text(data.error).parent().slideDown();
    }
}

function servicesError() {
    $('table .badge').each(function(index, event) {
        $(this).fadeIn().delay(100*index).fadeOut('fast', function(event) {
            $(this).text('Unknown').removeClass('badge-error badge-success').addClass('badge-warning');
        }).fadeIn('fast');
    });
}
