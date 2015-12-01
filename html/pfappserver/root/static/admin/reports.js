function init() {
    $('#section').on('section.loaded', function(event) {
        /* Initialize datepickers */
        $('.navbar').find('.datepicker').datepicker({ autoclose: true });

        /* Set the end date of the range datepickers to today */
        var today = new Date();
        $('.datepicker').find('input').each(function() { $(this).data('datepicker').setEndDate(today) });

        /* Register clicks on pre-defined periods */
        $('#reports .nav a').click(function(event) {
            event.preventDefault();
            var dp = $('.datepicker').data('datepicker');
            var dates = $(this).attr('href').substr(1).split('/');
            dp.pickers[0].element.val(dates[0]);
            dp.pickers[1].element.val(dates[1]);
            dp.pickers[0].update();
            dp.pickers[1].update();
            dp.pickers[0].element.trigger({ type: 'changeDate', date: dp.pickers[0].date });
            dp.pickers[1].element.trigger({ type: 'changeDate', date: dp.pickers[1].date });
        });

    /* Build graph when loading section */
        var id = $(this).find('.chart').attr('id');
        if (id)
            drawGraphs(id);
    });

    /* Reload section when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).closest('.datepicker').data('datepicker');
        var start = dp.dates[0];
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var end = dp.dates[1];
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        var graph = $('.piegraph a.active, .sidebar-nav .nav-list .active a').last().attr('href').substr(1);
        location.hash = [graph, startDate, endDate].join('/');
    });

    /* Hash change handlder */
    $(window).hashchange(pfOnHashChange(updateSection, '/graph/nodes'));
    $(window).hashchange();
    activateNavLink();
}
