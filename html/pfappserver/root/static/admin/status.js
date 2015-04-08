var refresh = {
    timeout: null,
    callback: reloadGraphs,
    delay: 60000 // in miliseconds
};

/*
 * This function is called at the initial loading of the page or when the window is resized.
 * In both cases, the default URL of the hashchange handler must be updated.
 * @see graphs.js
 */
function drawGraphs() {

    var href, pos,
      a = $('.sidebar-nav .nav-list a').first(),
      width = $('#dashboard').width();

    if (a) {
        // Add window width to dashboard link
        href = a.attr('href');
        pos = href.indexOf('?');
        if (pos >= 0)
            href = href.substring(0, pos);
        href += '?width=' + width;
        a.attr('href', href);
    }

    // Register hashchange handler with adjusted parameter (window width)
    if (location.hash.length > 0) {
        href = location.hash, pos = href.indexOf('?');
        if (pos >= 0)
            href = href.substring(0, pos);
        href = href.replace(/^.*#/,"/") + '?width=' + width;
        $(window).unbind('hashchange');
    }
    $(window).hashchange(pfOnHashChange(updateSection, href));

    // Trigger all event handlers with new hash that includes window width
    location.hash = href.replace(/^[#/]/, '');
}

function reloadGraphs() {
    var d = new Date();
    $('#dashboard img').each(function() {
        var that = $(this);
        that.attr('src', that.attr('data-src-base') + '&lastrefresh=' + d.getTime());
    });

    if (refresh.timeout)
        window.clearTimeout(refresh.timeout);
    refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
}

function init() {

    /* Reload dashboard when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).closest('.datepicker').data('datepicker');
        var start = dp.dates[0];
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var end = dp.dates[1];
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        var width = $('#dashboard').width();
        location.hash = ['graph', 'dashboard', startDate, endDate].join('/') + '?width=' + width;
    });

    /* Automatically refresh dashboard every X seconds */
    $('#section').on('section.loaded', function(event) {
        var section = $(this);
        if (section.children('#dashboard').length) {
            // Set the end date of the range datepickers to today
            var today = new Date();
            $('.datepicker').find('input').each(function() { $(this).data('datepicker').setEndDate(today) });

            // Set base url of images for automatic refresh (see reloadGraphs function)
            $('#dashboard img').each(function() {
                $(this).attr('data-src-base', this.src);
            });

            // Add window width to quick links of relative dates
            $('#dashboard .navbar a').each(function() {
                $(this).attr('href', this.href + '?width=' + $('#dashboard').width());
            });

            // Activate automatic refresh
            if (refresh.timeout)
                window.clearTimeout(refresh.timeout);
            refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
        }
        else {
            window.clearTimeout(refresh.timeout);
        }
    });

    drawGraphs();
    activateNavLink();
}
