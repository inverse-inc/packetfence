/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

function init() {
    $('#section').on('section.loaded', function(event) {
        /* Set the end date of the range datepickers to today */
        var today = new Date();
        $(this).find('.input-daterange input').each(function() {
            $(this).datepicker('setEndDate', today);
        });

        /* Register clicks on pre-defined periods */
        $('#reports .nav a').click(function(event) {
            event.preventDefault();
            var dp = $(this).closest('.container').find('.input-daterange').data('datepicker');
            var dates = $(this).attr('href').substr(1).split('/');
            dp.pickers[0].element.val(dates[0]);
            dp.pickers[1].element.val(dates[1]);
            dp.pickers[0].update();
            dp.pickers[1].update();
        });

        $('[id$="Empty"]').on('click', '[href="#add"]', function(event) {
            var match = /(.+)Empty/.exec(event.delegateTarget.id);
            var id = match[1];
            var emptyId = match[0];
            $('#'+id).trigger('addrow');
            $('#'+emptyId).addClass('hidden');
            return false;
        });

    /* Build graph when loading section */
        var id = $(this).find('.chart').attr('id');
        if (id)
            drawGraphs(id);
    });

    /* Reload section when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).parent().data('datepicker');
        if (!dp || !dp.dates) {
            return;
        }
        var start = dp.dates[0];
        var end = dp.dates[1];
        if (!start || !end) {
            return;
        }
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        var graph = $('.piegraph a.active, .sidenav-section .nav-list .active a').last().attr('href').substr(1);
        $(this).datepicker('hide');
        location.hash = [graph, startDate, endDate].join('/');
    });

    /* Hash change handlder */
    $(window).hashchange(pfOnHashChange(updateSection, '/graph/nodes'));
    $(window).hashchange();
    activateNavLink();
}
