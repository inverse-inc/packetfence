/*
 * Update an action input field depending on the selected action type.
 * Used in
 * - config/authentication.js
 * - config/users.js
 */
function updateAction(type, keep_value) {
    var action = type.val();
    var value = type.next();

    // Replace value field with the one from the templates
    var value_new = $('#' + action + '_action').clone();
    value_new.attr('id', value.attr('id'));
    value_new.attr('name', value.attr('name'));
    value_new.attr('data-required', 1);
    if (keep_value && value.val()) {
        if (value_new.attr('multiple')) {
            value_new.val(value.val().split(","));
        }
        else {
            value_new.val(value.val());
        }
    }
    value_new.insertBefore(value);
    value.next(".chzn-container").remove();

    // Remove previous field
    value.remove();
    // Initialize rendering widgets
    initWidgets(value_new);
}

/*
 * Initialize the rendering widgets of some elements
 */
function initWidgets(elements) {
    elements.filter('.chzn-select').chosen();
    elements.filter('.chzn-deselect').chosen({allow_single_deselect: true});
    elements.filter('.timepicker-default').each(function() {
        // Keep the placeholder visible if the input has no value
        var defaultTime = $(this).val().length? 'value' : false;
        $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
    });
    elements.filter('.datepicker').datepicker({ autoclose: true });
    if (elements.bootstrapSwitch)
        elements.filter('.switch').bootstrapSwitch();
}

function submitFormHideModal(modal,form) {
    $.ajax({
        'async' : false,
        'url'   : form.attr('action'),
        'type'  : form.attr('method') || "POST",
        'data'  : form.serialize()
        })
        .always(function()  {
            modal.modal('hide');
        })
        .done(function(data) {
            $(window).hashchange();
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
}
/* Trigger a mouse click on the active sidebar navigation link */
function activateNavLink() {
    var hash = location.hash;
    var found = false;
    if (hash && hash != '#') {
        // Find the longest match
        // Sort links by descending order by string length
        $('.sidebar-nav .nav-list a').sort(function(a,b){
           return b.href.length - a.href.length;
        })
        // Find the first link
        .filter(function(i,link) {
            if(false === found && hash.indexOf(link.hash) === 0) {
                found = true;
                return true;
            }
            return false;
        }).trigger('click');
    }
    if (false === found) {
        $('.sidebar-nav .nav-list a').first().trigger('click');
    }
}

/* Update #section using an ajax request */
function updateSection(ajax_data) {
    activateNavLink();
    var section = $('#section');
    if (section) {
        $("body,html").animate({scrollTop:0}, 'fast');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5, function() {
            $.ajax(ajax_data)
                .always(function() {
                    loader.hide();
                    section.fadeTo('fast', 1.0);
                    resetAlert(section);
                })
                .done(function(data) {
                    section.html(data);
                    section.find('.datepicker').datepicker({ autoclose: true });
                    section.find('.timepicker-default').each(function() {
                        // Keep the placeholder visible if the input has no value
                        var defaultTime = $(this).val().length? 'value' : false;
                        $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
                    });
                    if (section.chosen) {
                        section.find('.chzn-select:visible').chosen();
                        section.find('.chzn-deselect:visible').chosen({allow_single_deselect: true});
                    }
                    if (section.bootstrapSwitch)
                        section.find('.switch').bootstrapSwitch();
                    section.trigger('section.loaded');
                })
                .fail(function(jqXHR) {
                    var status_msg = getStatusMsg(jqXHR);
                    var alert_section = section.children('h1, h2, h3').first().next();
                    if (alert_section.length == 0) {
                        section.prepend('<h2></h2><div></div>');
                        alert_section = section.children().first().next();
                    }
                    showPermanentError(alert_section, status_msg);
                });
        });
    }
}
/* Update #section using an ajax request to a form */
function updateSectionFromForm(form) {
    updateSection({
        'url'  : form.attr('action'),
        'type' : form.attr('method') || "POST",
        'data' : form.serialize()
    });
}


/* Return a function to be called when the hash changes */
function pfOnHashChange(updater, default_url) {
    return function(event) {
        var hash = location.hash;
        var href = '/' + hash.replace(/^#\/*/,'');
        if (default_url !== undefined && (href == '' || href == '/')) {
            href = default_url;
        }
        updater(href);
        return true;
    };
}

/* Update sort handles and inputs indexes of sortable table */
function updateDynamicRows(rows) {
    rows.each(function(index, element) {
        $(this).find('.sort-handle').first().text(index +1);
        $(this).find(':input, [data-toggle="buttons-radio"] > a').each(function() {
            var input = $(this);
            var name = input.attr('name');
            var id = input.attr('id');
            if(name) {
                input.attr('name', name.replace(/\.[0-9]+/, '.' + index ));
            }
            if(id) {
                input.attr('id', id.replace(/\.[0-9]+/, '.' + index ));
            }
            if (this.tagName == 'SELECT') {
                $(this).find('option').each(function() {
                    var option = $(this);
                    var id = option.attr('id');
                    if(id) {
                        option.attr('id', id.replace(/\.[0-9]+\./, '.' + index + '.'));
                    }
                    var name = option.attr('name');
                    if(name) {
                        option.attr('name', name.replace(/\.[0-9]+\./, '.' + index + '.'));
                    }
                });
            }
        });
    });
}

function updateDynamicRowsAfterRemove(table) {
    var tbody = table.children("tbody");
    var rows = tbody.children(':not(.hidden)');
    if(table.hasClass("table-sortable") ) {
        rows = rows.filter(":has(.sort-handle)");
    }
    updateDynamicRows(rows);
    var count = rows.length;
    if (count < 2) {
        var id = '#' + table.attr('id') + 'Empty';
        if ($(id).length) {
            // The table can be empty
            if (count == 0) {
                if (tbody.prev('thead').length)
                    table.remove();
                $(id).removeClass('hidden');
            }
        }
        else if (count == 1) {
            // The table can't be empty
            tbody.children(':not(.hidden)').find('[href="#delete"]').addClass('hidden');
        }
    }
}

function updateExtendedDurationExample(group) {
    var fromElement = $('#extendedFrom');
    var fromDate = fromElement.data('date');
    var fromString = fromElement.html();
    var toElement = $('#extendedTo');

    function padZero(i) { return (i < 10)? '0'+i : i; };

    if (!fromDate) {
        // Initialize the reference date
        var now = new Date();
        fromString =
            now.getFullYear() + "-" + padZero(now.getMonth() + 1) + "-" + padZero(now.getDate()) + " " +
            padZero(now.getHours()) + ":" + padZero(now.getMinutes()) + ":" + padZero(now.getSeconds());
        fromElement.html(fromString);
        fromDate = Math.floor(now.getTime()/1000);
        fromElement.data('date', fromDate);
    }

    // Build duration representation
    var interval = group.find('[name$=".duration.interval"]').val();
    var unit = group.find('input[name$=".duration.unit"]').val();
    if (interval && unit) {
        var duration = interval + unit;
        var day_base = group.find('[name$="day_base"]').is(':checked');
        if (day_base) {
            var period_base = group.find('[name$="period_base"]').is(':checked');
            var e_duration = {
                operator: group.find('[name$="operator"]').val(),
                interval: group.find('[name$="extended_duration.interval"]').val(),
                unit: group.find('input[name$="extended_duration.unit"]').val()
            };
            duration += period_base? "R" : "F";
            if (e_duration.operator && e_duration.interval && e_duration.unit) {
                duration += (e_duration.operator == 'subtract')? "-" : "+";
                duration += e_duration.interval + e_duration.unit;
            }
            else {
                duration += '+0D';
            }
        }

        group.data('duration', duration);

        $.ajax(['/configuration', 'duration', fromDate, duration].join('/'))
            .done(function(data) {
                toElement.html(data.status_msg);
            });
    }
    else {
        toElement.html(fromString);
    }
}

$(function () { // DOM ready

    /* redirect to URL specified in the location header */
    var redirectCallback =  function(jqXHR) {
        var location = jqXHR.getResponseHeader('Location');
        if (location)
            // Reload the page and let the server render the proper template (most likely the login page)
            window.location.reload(true);
    };
    /* Default values for Ajax requests */
    $.ajaxSetup({
        timeout: 120000,
        cache: false,
        statusCode: {
            401: redirectCallback,
            302: redirectCallback
        }
    });

    /* Register links in the sidebar list */
    $('.sidebar-nav .nav-list a').click(function(event) {
        var item = $(this).parent();
        $('.sidebar-nav .nav-list .active').removeClass('active');
        item.addClass('active');
        return true;
    });

    /* Range datepickers
     * See https://github.com/eternicode/bootstrap-datepicker/tree/range */

    $('body').on('changeDate', '.datepicker input[name="start"]', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the start date of the second datepicker to this new date
        dp.pickers[1].setStartDate(event.date);
    });
    $('body').on('changeDate', '.datepicker input[name="end"]', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the end date of the first datepicker to this new date
        dp.pickers[0].setEndDate(event.date);
    });
    $('body').on('click', '.datepicker a[href*="day"]', function(event) {
        event.preventDefault();

        // The number of days is extracted from the href attribute
        var days = $(this).attr('href').replace(/#last([0-9]+)days?/, "$1");
        var dp = $(this).closest('.datepicker').data('datepicker');
        var nowDate = new Date();
        var now = {
            yyyy: nowDate.getFullYear(),
            m: (nowDate.getMonth() + 1),
            d: nowDate.getDate()
        };
        now.dd = (now.d < 10 ? '0' : '') + now.d;
        now.mm = (now.m < 10 ? '0' : '') + now.m;
        var beforeDate = new Date(nowDate.getTime() - days*24*60*60*1000);
        var before = {
            yyyy: beforeDate.getFullYear(),
            m: (beforeDate.getMonth() + 1),
            d: beforeDate.getDate()
        };
        before.dd = (before.d < 10 ? '0' : '') + before.d;
        before.mm = (before.m < 10 ? '0' : '') + before.m;

        // Start date
        var format = dp.pickers[0].element.attr('data-date-format');
        var before_str = format.replace('yyyy', before.yyyy).replace('mm', before.mm).replace('dd', before.dd);
        dp.pickers[0].element.val(before_str);
        dp.pickers[0].update();
        dp.pickers[0].setEndDate(beforeDate);
        dp.pickers[0].element.trigger({ type: 'changeDate', date: dp.pickers[0].date });

        // End date
        var format = dp.pickers[1].element.attr('data-date-format');
        var now_str = format.replace('yyyy', now.yyyy).replace('mm', now.mm).replace('dd', now.dd);
        dp.pickers[1].element.val(now_str);
        dp.pickers[1].update();
        dp.pickers[1].setStartDate(nowDate);
        dp.pickers[1].element.trigger({ type: 'changeDate', date: dp.pickers[1].date });

        dp.updateDates();

        return false;
    });

    /* Save the list order */
    $('#section').on('admin.ordered', '.admin_ordered', function(event) {
        var form = $(this).closest('form');
        $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: form.serialize()
        }).done(function(data) {
            resetAlert($('#section'));
            showSuccess(form, data.status_msg);
        }).fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError(form, status_msg);
        });
    });

    /* Activate sortable tables and lists (rows/items can be re-ordered) */
    $('body').on('mousemove',
                 '.table-sortable tbody tr:not(.ui-draggable), .list-sortable li:not(.ui-draggable)',
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
                        // Extract text from links, selects and static fields
                        $(this).find('a[class!="btn-icon"], :selected, .uneditable').map(function() {
                            if (!$(this).hasClass('btn'))
                                txt.push($(this).text());
                        });
                        // Extract text from input fields, except hidden and checkbox
                        $(this).find('input[type!="hidden"]:not(:checkbox)').map(function() {
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
            }
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
                updateDynamicRows(rows);
                dst.closest('table, ul').trigger('admin.ordered');
            }
        });
    });

    /* Activate dynamic tables (rows can be added and removed) */
    $('body').on('click', '.table-dynamic [href="#add"]', function(event) {
        $(this).trigger("addrow");
        return false;
    });

    $('body').on('addrow', '.table-dynamic', function(event) {
        var table = $(this);
        var row = table.find(event.target).closest('tr');

        var tbody = table.children('tbody');
        var row_model = tbody.children('.hidden').first();
        if (row_model) {
            var row_new = row_model.clone();
            row_new.removeClass('hidden');
            row_new.find(':input').removeAttr('disabled');
            row_new.find('.btn').removeClass('disabled');
            if (row.length > 0) {
                row_new.insertAfter(row);
            } else {
                row_new.insertBefore(row_model);
            }
            var rows = tbody.children(':not(.hidden)');
            if (table.hasClass("table-sortable") ) {
                rows = rows.filter(":has(.sort-handle)");
            }
            updateDynamicRows(rows);
            var count = rows.length;
            if (count >= 2) {
                var table = tbody.closest('table');
                var id = '#' + table.attr('id') + 'Empty';
                if ($(id).length) {
                    $(id).addClass('hidden');
                }
                tbody.children(':not(.hidden)').find('[href="#delete"]').removeClass('hidden');
            }
            row_new.trigger('admin.added');
        }
        return false;
    });

    $('body').on('click', '.table-dynamic [href="#delete"]', function(event) {
        $(this).trigger("deleterow");
        return false;
    });

    $('body').on('deleterow', '.table-dynamic', function(event) {
        var table = $(this);
        var row = table.find(event.target).closest('tr');
        var tbody = table.children('tbody');
        row.fadeOut('fast', function() {
            $(this).remove();
            // Update sort handle if the table is sortable
            //var empty = true;
            updateDynamicRowsAfterRemove(table);
            tbody.trigger('admin.deleted');
        });
        return false;
    });

    /* Activate links that trigger an ajax request and return a JSON status message */
    $('#section').on('click','a.updates_section_status_msg', function() {
        var that = $(this);
        var href = that.attr('href');
        var section = $('#section');
        var sibling = that.parent().next();
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
            showPermanentSuccess(sibling, data.status_msg);
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            if (jqXHR.status == 404) {
                showSuccess(sibling, status_msg);
            }
            else {
                showPermanentError(sibling, status_msg);
            }
        });
        return false;
    });

    $('#section').on('click', '.call-modal-confirm-link', function(event) {
        var that = $(this);
        if (that.hasClass('disabled'))
            return false;
        var url = that.attr('href');
        var modal_id = that.attr('data-target');
        var content  = that.attr('data-content');
        var modal = $(modal_id);
        modal.find('#content').html(content);
        var confirm_link = modal.find('a.btn-primary').first();
        modal.modal({ show: true });
        confirm_link.off('click');
        confirm_link.attr('href',url);
        confirm_link.click(function() {
            modal.modal('hide');
        });
        return false;
    });

    $('#section').on('click', '.call-modal-confirm-form', function(event) {
        var that = $(this);
        if (that.hasClass('disabled'))
            return false;
        var form;
        var modal_id = that.attr('data-modal');
        var form_id = that.attr('data-modal-form');
        var modal    = $('#' + modal_id);
        var content  = that.attr('data-content');
        var confirm_link = modal.find('a.btn-primary').first();
        if (form_id) {
            form = $('#' + form_id);
        } else {
            form = that.closest('form');
        }
        if (content) {
            modal.find('#content').html(content);
        }
        var valid = isFormValid(form);
        if (valid) {
            modal.modal({ show: true });
            confirm_link.off('click');
            confirm_link.click(function() {
                $.ajax({
                    'url'  : form.attr('action'),
                    'type' : form.attr('method') || "POST",
                    'data' : form.serialize()
                })
                    .always(function() {
                        modal.modal('hide');
                    })
                    .done(function(data) {
                        if (data.status_msg) {
                            $("body,html").animate({scrollTop:0}, 'fast');
                            showSuccess($('h2').first().next(), data.status_msg);
                        } else {
                            $(window).hashchange();
                        }
                    })
                    .fail(function(jqXHR) {
                        $("body,html").animate({scrollTop:0}, 'fast');
                        var status_msg = getStatusMsg(jqXHR);
                        showError($('#section h2'), status_msg);
                    });
                return false;
            });
        }
        return false;
    });

    $('#section').on('click', '.call-modal', function(event) {
        var that = $(this);
        if (that.hasClass('disabled'))
            return false;
        var url = that.attr('href');
        var modal_id = that.attr('data-modal');
        var content  = that.attr('data-modal-content');
        var modal = $('#' + modal_id);
        if(content) {
            modal.find('#content').html(content);
        }
        var confirm_link = modal.find('a.btn-primary').first();
        modal.modal({ show: true });
        confirm_link.off('click');
        confirm_link.click(function() {
            $.ajax(url)
                .always(function() {
                    modal.modal('hide');
                })
                .done(function(data) {
                    $(window).hashchange();
                })
                .fail(function(jqXHR) {
                    $("body,html").animate({scrollTop:0}, 'fast');
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section h2'), status_msg);
                });
            return false;
        });

        return false;
    });

    $('#section').on('click',
        '[data-toggle="modal"][data-target][data-href-background]',
        function(event) {
            var that  = $(this);
            var href  = that.attr("data-href-background");
            var modal = $(that.attr("data-target"));
            var button = modal.find(".btn-primary").first();
            button.off('click');
            button.click(function() {
                $.ajax(href)
                    .done(function(data) {
                        $(window).hashchange();
                    })
                    .fail(function(jqXHR) {
                        $("body,html").animate({scrollTop:0}, 'fast');
                        var status_msg = getStatusMsg(jqXHR);
                        showError($('#section h2'), status_msg);
                    })
            });
    });

    /* Add an extended duration to a text input field */
    $('#section').on('click', '#addExtendedTime', function(event) {
        var btn = $(this);
        var group = btn.closest('.extended-duration');
        var duration = group.data('duration'); // set in updateExtendedDurationExample
        if (duration) {
            var input = $(btn.data('target'));
            var str = input.val();
            var found = false;
            $.each(str.split(/ *, */), function(index, value) {
                if (value == duration) {
                    found = true;
                    return false;
                }
            });
            if (!found)
                input.val(str? str + "," + duration : duration);
        }

        return false;
    });

    /* Update any extended duration examples when loading section */
    $('body').on('section.loaded', function(event) {
        updateExtendedDurationExample($('.extended-duration'));
    });

    /* Update extended duration widget when changing parameters of the duration */
    $('#section').on('change', '.extended-duration', function(event) {
        var input = $(event.target);
        var group = input.closest('.extended-duration');

        if (input.is('[name$="day_base"]')) {
            // Advanced options are available only if "relative to the beginning of the day" is checked
            var enabled = input.is(':checked');
            if (enabled)
                group.find('[name*=extended_duration], [name$=period_base]').removeAttr('disabled').removeClass('disabled');
            else {
                group.find('input[name*=extended_duration], select[name*=extended_duration], input[name$=period_base]').attr('disabled', 'disabled');
                group.find('a[name*=extended_duration]').addClass('disabled');
            }
        }

        updateExtendedDurationExample(group);
    });

    if (typeof init == 'function') init();
    if (typeof initModals == 'function') initModals();

    $('#checkup_dropdown_toggle').click(function () {
      if($(this).closest('li').hasClass('open')) {
        $.get("/admin/checkup", function(data){
          var dropdown = $('#checkup_dropdown');
          dropdown.html('');
          if(data.items.problems.length > 0){
            for(var i in data.items.problems){
              var li = $('<li class="disabled"><a href="#">'+data.items.problems[i].severity+' : '+data.items.problems[i].message+'</a></li>');
              dropdown.append(li);
            }
          }
          else{
            var li = $('<li class="disabled"><a href="#">No problem detected !</a></li>');
            dropdown.append(li);
          }
        });
      }
    });

});
