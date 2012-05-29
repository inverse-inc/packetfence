function registerExists() {
    $('.form-actions a').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function saveStep(href) {

    $('table .badge').each(function(index, event) {
        $(this).fadeIn().delay(5000*index).fadeOut('fast', function(event) {
            $(this).text('Starting').addClass('badge-warning');
        }).fadeIn('fast').delay(3000).fadeOut('fast', function(event) {
            $(this).text('Started').removeClass('badge-warning').addClass('badge-success');
        }).fadeIn('fast', function(event) {
            if (index == 7) {
                $('#modalRedirection').modal({ show: true });
                window.setTimeout(function(event) { window.location.href = 'https://localhost:1443/'; }, 40000);
            }
        });
    });

    $.ajax({
        type: 'POST',
        url: window.location.pathname
    }).done(function(data) {
        resetAlert($('#services'));
        showSuccess($('#services table'), data.status_msg);
    }).fail(function(jqXHR) {
        var obj = $.parseJSON(jqXHR.responseText);
        showError($('#services table'), obj.status_msg);
    });

}
