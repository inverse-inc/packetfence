var refresh = {
    timeout: null,
    callback: function() { $(window).hashchange(); },
    delay: 60000 // in miliseconds
};

function updateGraphSection(graph) {
    var dp = $('.datepicker').data('datepicker');
    var start = dp.dates[0];
    var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
    var end = dp.dates[1];
    var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
    if (!graph) {
        var section = $('#section');
        var name = section.find('.nav .active a').attr('href');
        var tab = $(name.substr(name.indexOf('#')));
        if (tab.length) {
            graph = tab.find('.graph:first');
        }
        else {
            return;
        }
    }
    var url = [graph.attr('data-uri'), startDate, endDate];
    var href = url.join('/');
    $.ajax(href)
        .done(function(data) {
            graph.html(data);
            var id = graph.find('.chart').attr('id');
            if (id)
                drawGraphs(id);
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(graph, status_msg);
        });

    return false;
}

function init() {

    /* Reload dashboard when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).closest('.datepicker').data('datepicker');
        var start = dp.dates[0];
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var end = dp.dates[1];
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        location.hash = ['graph', 'dashboard', startDate, endDate].join('/');
    });

    /* Automatically refresh dashboard every X seconds */
    $('#section').on('section.loaded', function(event) {
        var section = $(this);
        if (section.children('#dashboard').length) {
            updateGraphSection();

            // Set the end date of the range datepickers to today
            var today = new Date();
            $('.datepicker').find('input').each(function() { $(this).data('datepicker').setEndDate(today) });

            if (refresh.timeout)
                window.clearTimeout(refresh.timeout);
            refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
        }
        else {
            window.clearTimeout(refresh.timeout);
        }
    });

    /* Build graph when changing tab on the dashboard */
    $('#section').on('shown', 'a[data-toggle="tab"]', function(event) {
        var name = $(event.target).attr('href');
        var tab = $(name.substr(name.indexOf('#')));
        var graph = tab.find('.graph:first');
        updateGraphSection(graph)
    });

    $('#section').on('click', '[data-href-background]', function() {
        var that = $(this);
        var href = that.attr('data-href-background');
        var section = $('#section');
        var loader = section.prev('.loader');
        if (loader) loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(href)
            .always(function(){
                if (loader) loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                $(window).hashchange();
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError($("#section .table"), status_msg);
            });
        return false;
    });

    /* Hash change handler */
    $(window).hashchange(pfOnHashChange(updateSection, '/graph/dashboard/'));
    $(window).hashchange();
    activateNavLink();
}
