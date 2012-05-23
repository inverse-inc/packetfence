function registerExists() {
    $('.form-actions a').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function saveStep(href) {
    $('table .badge').each(function(index, event) {
        $(this).fadeIn().delay(1000*index).fadeOut('fast', function(event) {
            $(this).text('Starting').addClass('badge-warning');
        }).fadeIn('fast').delay(2000).fadeOut('fast', function(event) {
            $(this).text('Started').removeClass('badge-warning').addClass('badge-success');
        }).fadeIn('fast');
    });
}