$(function () {
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
    
    /* Activate sortable tables and lists (rows/items can be re-ordered) */
    $('body').on('mousemove',
                 '.table-sortable tr:not(.ui-draggable), .list-sortable li:not(.ui-draggable)',
                 function() {
        var row = $(this);
        var id = row.closest('table, ul').attr('id');
        row.draggable({
            scope: id,
            handle: '.sort-handle',
            appendTo: 'body',
            cursor: 'move',
            helper: function(event) {
                var txt = new Array();
                if (event.target.tagName == 'TD') {
                    var row = $(event.target).closest('tr').first();
                    row.find('td').each(function () {
                        $(this).find('a[class!="btn-icon"], :selected').map(function() {
                            if (!$(this).hasClass('btn'))
                                txt.push($(this).text());
                        });
                        $(this).find('input[type!="hidden"]').map(function() {
                            txt.push($(this).val());
                        });
                    });
                }
                else {
                    var a = $(event.target).closest('li').find('a').first().clone();
                    // Remove the sort-handle
                    a.find('span').remove();
                    txt.push(a.text());
                }
                return $('<div class="drag-row">' + txt.join(' ') + '</div>');
            },
        });
        row.siblings().droppable({
            scope: id,
            accept: function(obj) {
                var delta = 0;
                if (obj.context.tagName == 'TR') {
                    var dragIndex = obj.context.rowIndex;
                    var dropIndex = this.rowIndex;
                    delta = dropIndex - dragIndex;
                }
                else {
                    var items = $(this).closest('ul').children();
                    var dragIndex = items.index(obj);
                    var dropIndex = items.index(this);
                    delta = dropIndex - dragIndex;
                }
                return (delta < 0 || delta > 1);
            },
            hoverClass: 'drop-row',
            drop: function(event, ui) {
                var src = ui.draggable.detach();
                var dst = $(this);
                src.insertBefore(dst);

                // Update indexes
                var rows = dst.siblings(':not(.hidden)').andSelf();
                rows.each(function(index, element) {
                    $(this).find('.sort-handle').first().text(index +1);
                    $(this).find(':input').each(function() {
                        var input = $(this);
                        var name = input.attr('name');
                        var id = input.attr('id');
                        input.attr('name', name.replace(/\.[0-9]+\./, '.' + index + '.'));
                        input.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                        if (this.tagName == 'SELECT') {
                            $(this).find('option').each(function() {
                                var option = $(this);
                                var id = option.attr('id');
                                if (id)
                                    option.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                            });
                        }
                    });
                });

                dst.closest('table').trigger('admin.ordered');
            }
        });
    });

    /* Activate dynamic tables (rows can be added and removed) */
    $('body').on('click', '.table-dynamic [href="#add"]', function(event) {
        var tbody = $(this).closest('tbody');
        var row = $(this).closest('tr');
        var row_model = tbody.children('.hidden').first();
        if (row_model) {
            var row_new = row_model.clone();
            row_new.removeClass('hidden');
            row_new.insertAfter(row);
            row_new.trigger('admin.added');
        }
        // Update indexes
        var count = 0;
        tbody.children(':not(.hidden)').each(function(index, element) {
            count++;
            $(this).find('.sort-handle').first().text(index + 1);
            $(this).find(':input').each(function() {
                var input = $(this);
                var name = input.attr('name');
                var id = input.attr('id');
                input.attr('name', name.replace(/\.[0-9]+\./, '.' + index + '.'));
                input.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                if (this.tagName == 'SELECT') {
                    $(this).find('option').each(function() {
                        var option = $(this);
                        var id = option.attr('id');
                        if (id)
                            option.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                    });
                }
            });
            $(this).find('[href="#delete"]').removeClass('hidden')
        });
    });
    $('body').on('click', '.table-dynamic [href="#delete"]', function(event) {
        var tbody = $(this).closest('tbody');
        $(this).closest('tr').fadeOut('fast', function() {
            $(this).remove();
            // Update sort handle if the table is sortable
            //var empty = true;
            var count = 0;
            tbody.children(':not(.hidden)').each(function(index, element) {
                $(this).find('.sort-handle').each(function() {
                    $(this).text(index + 1);
                    //empty = false;
                    count++;
                });
            });
            if (count < 2) {
                var table = tbody.closest('table');
                var id = '#' + table.attr('id') + 'Empty';
                if ($(id).length) {
                    if (count == 0) {
                        if (tbody.prev('thead').length)
                            table.remove();
                        $(id).removeClass('hidden');
                    }
                }
                else if (count == 1) {
                    tbody.children(':not(.hidden)').find('[href="#delete"]').addClass('hidden');
                }
            }
        });
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

function updateSortableTable(rows) {
    rows.each(function(index, element) {
        $(this).find('.sort-handle').first().text(index +1);
        $(this).find(':input').each(function() {
            var input = $(this);
            var name = input.attr('name');
            var id = input.attr('id');
            input.attr('name', name.replace(/\.[0-9]+\./, '.' + index + '.'));
            input.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
            if (this.tagName == 'SELECT') {
                $(this).find('option').each(function() {
                    var option = $(this);
                    var id = option.attr('id');
                    option.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                });
            }
        });
    });
}