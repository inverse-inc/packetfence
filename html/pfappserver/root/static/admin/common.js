$(function () {
    $('.dropdown-toggle').dropdown();

    /* Range datepickers
     * See https://github.com/eternicode/bootstrap-datepicker/tree/range */
    $('.datepicker input[name="start"]').on('changeDate', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the start date of the second datepicker to this new date
        dp.pickers[1].setStartDate(event.date);
    });
    $('.datepicker input[name="end"]').on('changeDate', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the end date of the first datepicker to this new date
        dp.pickers[0].setEndDate(event.date);
    });
    $('.datepicker a[href*="day"]').click(function() {
        // The number of days is extracted from the href attribute
        var days = $(this).attr('href').replace(/#last([0-9]+)days?/, "$1");
        var dp = $(this).parent().data('datepicker');
        var now = new Date();
        var before = new Date(now.getTime() - days*24*60*60*1000);
        var now_str = (now.getMonth() + 1) + '/' + now.getDate() + '/' + now.getFullYear();
        var before_str = (before.getMonth() + 1) + '/' + before.getDate() + '/' + before.getFullYear();
        
        // Start date
        dp.pickers[0].element.val(before_str);
        dp.pickers[0].update();
        dp.pickers[0].setEndDate(now);

        // End date
        dp.pickers[1].element.val(now_str);
        dp.pickers[1].update();
        dp.pickers[1].setStartDate(before);

        dp.updateDates();
    });
    
    /* Advanced search tables */
    $('.table-search').on('click', '[href="#add"]', function(event) {
        var rows = $(this).closest('tbody').children();
        var row_model = rows.filter('.hidden').first();
        var row = row_model.clone();
        row.removeClass('hidden');
        row.insertBefore(rows.last());
    });
    $('.table-search').on('click', '[href="#delete"]', function(event) {
        if (!$(this).hasClass('disabled'))
            $(this).closest('tr').remove();
    });

    /* Pagination */
    $('#results').on('click', '.pagination a', function(event) {
        var results = $('#results');
        results.fadeTo('fast', 0.5);
        $.ajax($(this).attr('href'))
        .done(function(data) {
            results.html(data).fadeTo('fast', 1.0);
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError(results, obj.status_msg);
            results.fadeTo('fast', 1.0);
        });
        return false;
    });

    if (typeof init == 'function') init();
    if (typeof initModals == 'function') initModals();
});