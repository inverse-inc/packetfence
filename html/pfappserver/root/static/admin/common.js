/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */
/* jshint evil: true */

/*
 * Update an action input field depending on the selected action type.
 * Used in
 * - config/authentication.js
 * - config/users.js
 */

function update_attribute(element, name, regex, replace_str) {
    var new_attr = element.attr(name);
    if (new_attr !== undefined) {
        new_attr = new_attr.replace(regex, replace_str);
        element.attr(name, new_attr);
    }
}

function update_attributes(element, name, query, regex, replace_str) {
    update_attribute(element, name, regex, replace_str);
    element.find(query).each(function(){
        update_attribute($(this), name, regex, replace_str);
    });
}


function escapeRegExp(string){
    return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

function dynamic_list_update_all_attributes(elements, base_id, count) {

    /*
     * Update id
     */

    elements.find('.sort-handle').first().text(count +1);
    var regex_str = base_id + "\\." + "[0-9]+";
    var regex = new RegExp(regex_str);
    var replace_str = base_id + "." + count.toString();
    update_attributes(elements, "id", '[id*="' + base_id + '."]', regex, replace_str);
    update_attributes(elements, "data-base-id", '[data-base-id*="' + base_id + '."]', regex, replace_str);
    update_attributes(elements, "data-template-parent", '[data-template-parent*="' + base_id + '."]', regex, replace_str);
    update_attributes(elements, "name", '[name^="' + base_id + '."]', regex, replace_str);
    update_attributes(elements, "for", '[for^="' + base_id + '."]', regex, replace_str);

    /*
     * Update href and targets there are escaped
     */
    var jquery_escaped_id = escapeJqueryId(base_id + ".");
    var href_regex = new RegExp(escapeRegExp(jquery_escaped_id) + "[0-9]+");
    var href_replace = jquery_escaped_id + count.toString();
    $.each(["data-template-control-group", "href", "data-target-wrapper", "data-target", "data-template-parent", "data-sortable-item"], function(i, id) {
        var query = '[' + id + '*="' + escapeJqueryId(jquery_escaped_id) + '"]';
        update_attributes(elements, id, query, href_regex, href_replace);
    });
}

function updateAction(type, keep_value) {
    var action = type.val();
    var value = type.next();
    changeInputFromTemplate(value, $('#' + action + '_action'), keep_value);
}

/* Update a rule condition input field depending on the type of the selected attribute */
function updateCondition(attribute) {
    var type = attribute.find(':selected').attr('data-type');
    var operator = attribute.next();

    if (type != operator.attr('data-type')) {
        // Disable fields to be replaced
        var value = operator.next();
        operator.attr('disabled', 1);
        value.attr('disabled', 1);

        // Replace operator field
        var operator_new = $('#' + type + '_operator').clone();
        $.each(["id", "name", "data-required"], function(i, attr) {
            operator_new.attr(attr, operator.attr(attr));
        });
        operator_new.insertBefore(operator);

        // Replace value field
        var value_new = $('#' + type + '_value').clone();
        $.each(["id", "name", "data-required"], function(i, attr) {
            value_new.attr(attr, value.attr(attr));
        });
        value_new.insertBefore(value);

        if (!operator.attr('data-type')) {
            // Preserve values of an existing condition
            operator_new.val(operator.val());
            value_new.val(value.val());
        }

        // Remove previous fields
        value.remove();
        operator.remove();

        // Remember the data type
        operator_new.attr('data-type', type);

        // Initialize rendering widgets
        initWidgets(value_new);
    }
}

/* Update a rule condition input field depending on the type of the selected attribute */
function updateSoureRuleCondition(attribute, keep) {
    var type = attribute.find(':selected').attr('data-type');
    var operator = attribute.next();

    if (type != operator.attr('data-type')) {
        // Disable fields to be replaced
        var value = operator.next();
        var op_id = "#" + escapeJqueryId(operator.attr("id"));
        operator.attr('disabled', 1);
        value.attr('disabled', 1);

        // Replace operator field
        var operator_template = $('#' + type + '_operator');
        changeInputFromTemplate(operator, operator_template, keep);

        // Replace value field
        var value_template = $('#' + type + '_value');
        changeInputFromTemplate(value, value_template, keep);

        // Remember the data type
        $(op_id).attr('data-type', type);

    }
}


function escapeJqueryId( myid ) {
    return myid.replace( /(:|\.|\[|\]|,|=|\\)/g, "\\$1" );
}


function changeInputFromTemplate(oldInput, template, keep_value) {
    var newInput = template.clone();
    // Replace value field with the one from the templates
    newInput.removeAttr('id');
    newInput.attr('id', oldInput.attr('id'));
    newInput.attr('name', oldInput.attr('name'));
    newInput.attr('data-required', oldInput.attr('data-required'));
    if (keep_value && oldInput.val()) {
        if (newInput.attr('multiple')) {
            newInput.val(oldInput.val().split(","));
        }
        else {
            newInput.val(oldInput.val());
        }
    }
    newInput.insertBefore(oldInput);
    oldInput.next(".chosen-container").remove();

    // Remove previous field
    oldInput.remove();
    // Initialize rendering widgets
    initWidgets(newInput);
}

/*
 * Checks if element has a modal as a parent
 */
function has_parent_modal() {
    return $(this).parents('.modal').length > 0;
}

/*
 * Checks if element does not have a modal as a parent
 */
function has_no_parent_modal() {
    return $(this).parents('.modal').length === 0;
}

/*
 * Initialize the rendering widgets of some elements
 */
function initWidgets(elements) {
    var chzn_select = elements.filter('.chzn-select');
    // Chosen select must have a zero width in modal
    chzn_select.filter(has_parent_modal).chosen({width:''});
    chzn_select.filter(has_no_parent_modal).chosen({});
    fixChosenClipping(chzn_select);
    var chzn_deselect = elements.filter('.chzn-deselect');
    // Chosen deselect must have a zero width in modal
    chzn_select.filter(has_parent_modal).chosen({allow_single_deselect: true, width:''});
    chzn_select.filter(has_no_parent_modal).chosen({allow_single_deselect: true});
    fixChosenClipping(chzn_deselect);
    elements.filter('.timepicker-default').each(function() {
        // Keep the placeholder visible if the input has no value
        var defaultTime = $(this).val().length? 'value' : false;
        $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
    });
    elements.filter('.input-date, .input-daterange input').datepicker({ autoclose: true });
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

/**
 * Trigger a mouse click on the sidebar navigation link matching the current location hash.
 */
function activateNavLink() {
    var hash = location.hash;
    var found = false;
    var link = null;
    if (hash && hash != '#') {
        // Find the longest match
        // Sort links by descending order by string length
        link = $('.sidenav .nav a').sort(function(a,b) {
            return b.href.length - a.href.length;
        })
        // Find the first link
        .filter(function(i,link) {
            if (false === found && hash.indexOf(link.hash) === 0) {
                found = true;
                return found;
            }
            return false;
        });
    }
    if (link === null)
        link = $('.sidenav .nav a').first();

    link.trigger('click');
}

/* Update #section using an ajax request */
function updateSection(ajax_data) {
    activateNavLink();
    return doUpdateSection(ajax_data);
}

function doUpdateSection(ajax_data) {
    var section = $('#section');
    if (section) {
        $("body,html").animate({scrollTop:0}, 'fast');
        section.loader();
        section.fadeTo('fast', 0.5, function() {
            $.ajax(ajax_data)
                .always(function() {
                    section.fadeTo('fast', 1.0, function() {
                        section.loader('hide');
                    });
                    resetAlert(section);
                })
                .done(function(data) {
                    section.empty();
                    section.append(data);
                    section.find('.input-date, .input-daterange').datepicker({ autoclose: true });
                    section.find('.input-daterange input').on('changeDate', function(event) {
                        // Force autoclose
                        $('.datepicker').remove();
                    });
                    section.find('.timepicker-default').each(function() {
                        // Keep the placeholder visible if the input has no value
                        var defaultTime = $(this).val().length? 'value' : false;
                        $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
                    });
                    section.find('.chzn-select:visible').chosen();
                    section.find('.chzn-deselect:visible').chosen({allow_single_deselect: true, search_contains: true});
                    fixChosenClipping(section.find('.chzn-select:visible, .chzn-deselect:visible'));
                    section.find('.switch').bootstrapSwitch();
                    if (typeof ClipboardJS !== 'undefined' && ClipboardJS.isSupported())
                        section.find('.clipboard .icon-clipboard').tooltip({ title: _('Copy') });
                    else
                        section.find('.clipboard .icon-clipboard').remove();
                    section.trigger('section.loaded');
                })
                .fail(function(jqXHR) {
                    var status_msg = getStatusMsg(jqXHR);
                    var alert_section = section.find('h1, h2, h3').first().next();
                    if (alert_section.length === 0) {
                        section.prepend('<div class="card-actions"><h2></h2><div></div></div>');
                        alert_section = section.find('h2').first().next();
                    }
                    showPermanentError(alert_section, status_msg);
                });
        });
    }
    return true;
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
        if (default_url !== undefined && (href === '' || href == '/')) {
            href = default_url;
        }
        return updater(href,event);
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
            if (count === 0) {
                if (tbody.prev('thead').length && tbody.attr('data-no-remove') != "yes" )
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

jQuery.fn.extend({
  setBindId : function() {
    return this.each(function() {
      var o = this;
      // Ensure we don't bind the search twice by recording which IDs we've already set it up on
      // The ID is generated and assigned to a data tag to make sure duplicate HTML ids don't break this flow even though they aren't valid
      if(!$(o).attr('data-do-bind-id')) {
        var gen_id = $("<a></a>").uniqueId().attr('id');
        $(o).attr('data-do-bind-id', gen_id);
      } 
    });
  },
  /* 
   * Ensures that the function passes in parameter will only be executed once for an element of the DOM 
   * Useful to bind click events when objects load without double affecting the event to existing elements
   *
   */
  doOnce : function(eventId, func) {
    if(!$.pfBindedEvents) $.pfBindedEvents = {};
    if(!$.pfBindedEvents[eventId]) $.pfBindedEvents[eventId] = {};

    return this.each(function() {
      var o = this;
      $(o).setBindId();
      if($.pfBindedEvents[eventId][$(o).attr('data-do-bind-id')]) {
        return;
      }
      else {
        $.pfBindedEvents[eventId][$(o).attr('data-do-bind-id')] = true;
        $.proxy(func, this)();
      }
    });
  },
});

function bindExportCSV() {
  var btnClass = '.exportCSVBtn';
  $(btnClass).doOnce(btnClass, function(){
    var o = this;
    $(o).click(function() {
      window.location = $(o).attr('data-export-url')+'?'+$($(o).attr('data-export-form')).serialize()+"&export=export";
    });
  });
}

function updateExtendedDurationExample(group) {
    var fromElement = $('#extendedFrom');
    var fromDate = fromElement.data('date');
    var fromString = fromElement.html();
    var toElement = $('#extendedTo');

    function padZero(i) { return (i < 10)? '0'+i : i; }

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
    var unit = group.find('[name$=".duration.unit"]').val();
    if (interval && unit) {
        var duration = interval + unit;
        var day_base = group.find('[name$="day_base"]').is(':checked');
        if (day_base) {
            var period_base = group.find('[name$="period_base"]').is(':checked');
            var e_duration = {
                operator: group.find('[name$="operator"]').val(),
                interval: group.find('[name$="extended_duration.interval"]').val(),
                unit: group.find('[name$="extended_duration.unit"]').val()
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

function searchSwitchesGenerator(errorSibling) {
    return function(query, process) {
        $.ajax({
                url : '/config/switch/search',
                type : 'POST',
                data: {
                    'json': 1,
                    'all_or_any': 'any',
                    'searches.0.name': 'id',
                    'searches.0.op': 'like',
                    'searches.0.value': query,
                },
            })
            .done( function(data) {
                var results = $.map(data.items, function(i) {
                    return i.id;
                });
                process(results);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showError(errorSibling, status_msg);
            });
    };
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
    function _enableCategory(category) {
        // Activate corresponding category
        $('.sidenav-category .active').filter(function(i, li) {
            if ($(li).attr('data-category') != category)
                $(li).removeClass('active');
        });
        $('.sidenav-category [data-category="' + category + '"]').addClass('active');
        // Show corresponding list of sections
        $('.sidenav-fluid .sidenav-section').each(function() {
            var $section = $(this);
            if ($section.attr('data-category') == category)
                $section.removeClass('hide');
            else
                $section.addClass('hide');
        });
        $('.sidenav-fluid .sidenav-section .active').removeClass('active');
    }
    $('.sidenav-category a').click(function(event) {
        var li = $(this).parent();
        var category = li.attr('data-category');
        _enableCategory(category);
        return true;
    });
    $('.sidenav-section a:not([data-toggle]):not([target])').click(function(event) {
        var item = $(this).parent();
        var category = item.closest('.sidenav-section').attr('data-category');
        _enableCategory(category);

        if(item.hasClass('subsection')) {
          item.closest('.section').addClass('active');
        }
        
        item.addClass('active');

        // Define the first element as active if there is none selected
        if(item.hasClass('section') && item.find('ul').find('li.active').length === 0) {  
          $(item.find('ul').find('li')[0]).addClass('active');
        }

        return true;
    });

    $('body').on('click', 'a[data-toggle="date-picker"]', function(event) {
        event.preventDefault();
        var a = $(event.currentTarget);
        $.ajax({
            url : a.attr('href'),
            type : 'POST'
        }).done(function(data){
            var start_date_id = a.attr("data-start-date");
            var start_time_id = a.attr("data-start-time");
            var end_date_id = a.attr("data-end-date");
            var end_time_id = a.attr("data-end-time");
            var time_offset = data.time_offset;
            var start = time_offset.start;
            var end = time_offset.end;
            if (start_date_id) {
                var start_date_input = $(start_date_id);
                start_date_input.datepicker("setDate", start.date);
            }
            if (start_time_id) {
                var start_time_input = $(start_time_id);
                start_time_input.timepicker("setTime", start.time);
            }
            if (end_date_id) {
                var end_date_input = $(end_date_id);
                end_date_input.datepicker("setDate", end.date);
            }
            if (end_time_id) {
                var end_time_input = $(end_time_id);
                end_time_input.timepicker("setTime", end.time);
            }
        });
        return false;
    });

    /* Register events for animation of sidebar tooltips */
    $('.sidenav-category').on('mouseenter', '[data-category]', function(event) {
        var $this = $(this);
        var category = $this.data('category');
        var isActive = $this.hasClass('active');
        $('.sidenav-category-extend').addClass('show').find('li').each(function() {
            var $this = $(this);
            if (!isActive && $this.data('category') == category)
                $this.addClass('show');
            else
                $this.removeClass('show');
        });
    });
    $('.sidenav-category').on('mouseleave mouseup', '[data-category]', function(event) {
        $('.sidenav-category-extend').removeClass('show')
            .find('[data-category]').removeClass('show');
    });

    /* Enable tooltip in top navbar */
    $('#navbar [data-toggle="tooltip"]').tooltip({placement: 'bottom'});

    /* Configure tooltips of "copy to clipboard" buttons */
    if (typeof ClipboardJS !== "undefined" && ClipboardJS.isSupported()) {
        var clipboard = new ClipboardJS('.icon-clipboard.btn-icon');
        clipboard.on('success', function(e) {
            var btn = $(e.trigger);
            btn.tooltip('destroy').tooltip({ title: _('Copied') }).tooltip('show');
            setTimeout(function() {
                btn.tooltip('destroy').tooltip({ title: _('Copy') });
            }, 3000);
        });
    }

    $('body').on('click', '[data-toggle="dynamic-list"]', function(event) {
        event.preventDefault();
        var link = $(this);
        var target = $(link.attr("data-target"));
        var target_wrapper = $(link.attr("data-target-wrapper"));
        var template_parent = $(link.attr("data-template-parent"));
        var template_control_group = $(link.attr("data-template-control-group"));
        var base_id = link.attr("data-base-id");
        var copy = template_parent.clone();
        copy.removeAttr('id');
        copy.find(':input').each(function(i,e) {
            var input = $(e);
            var template_parent = input.closest('[id^="dynamic-list-template"]');
            if (template_parent.length === 0) {
                input.removeAttr('disabled');
                input.removeClass('disabled');
            }
        });
        var index = target.children().length;
        dynamic_list_update_all_attributes(copy, base_id, index);
        target.append(copy.children());
        target_wrapper.removeClass('hidden');
        template_control_group.addClass('hidden');
        target.children().last().trigger('dynamic-list.add');
        return false;
    });


    $('body').on('click', '[data-toggle="dynamic-list-delete"]', function(event) {
        event.preventDefault();
        var link = $(this);
        var target_wrapper = $(link.attr("data-target-wrapper"));
        var data_target = $(link.attr("data-target"));
        var base_id = link.attr("data-base-id");
        var siblings = data_target.siblings();
        var template_control_group = $(link.attr("data-template-control-group"));
        data_target.remove();
        if (siblings.length === 0) {
            target_wrapper.addClass('hidden');
            template_control_group.removeClass('hidden');
        } else {
            siblings.each(function(i,e) {
                dynamic_list_update_all_attributes($(e), base_id, i);
            });
        }
        return false;
    });

    /* Range datepickers
     * See https://github.com/eternicode/bootstrap-datepicker/tree/range */

    $('body').on('changeDate', '.input-daterange input[name="start"]', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the start date of the second datepicker to this new date
        $(dp.inputs[1]).datepicker('setStartDate', event.date);
    });
    $('body').on('changeDate', '.input-daterange input[name="end"]', function(event) {
        var dp = $(this).parent().data('datepicker');
        // Limit the end date of the first datepicker to this new date
        $(dp.inputs[0]).datepicker('setEndDate', event.date);
    });
    $('body').on('click', '.input-daterange a[href*="day"]', function(event) {
        event.preventDefault();

        // The number of days is extracted from the href attribute
        var days = $(this).attr('href').replace(/#last([0-9]+)days?/, "$1");
        var dp = $(this).closest('.input-daterange').data('datepicker');
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
        format = dp.pickers[1].element.attr('data-date-format');
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
                var txt = [];
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
                var dragIndex;
                var dropIndex;
                var contextObj = obj.first()[0];
                if (contextObj.tagName == 'TR') {
                    dragIndex = contextObj.rowIndex;
                    dropIndex = this.rowIndex;
                    delta = dropIndex - dragIndex;
                }
                else {
                    var items = $(this).closest('ul').children();
                    dragIndex = items.index(obj);
                    dropIndex = items.index(this);
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
                var rows = dst.siblings(':not(.hidden)').addBack();
                updateDynamicRows(rows);
                dst.closest('table, ul').trigger('admin.ordered');
            }
        });
    });

    /* Activate sortable divs (divs can be re-ordered) */
    $('body').on('mousemove',
                 '.dynamic-list-sortable .sort-handle:not(.ui-draggable)',
                 function() {
        var row = $(this);
        var scope = row.attr('data-sortable-scope');
        var item = $(row.attr('data-sortable-item'));
        item.draggable({
            scope: scope,
            handle: '.sort-handle',
            appendTo: 'body',
            cursor: 'move',
            helper: function(event) {
                var target = $(event.target);
                return '<div class="drag-row">' + target.attr('data-sortable-text') + '</div>';
            }
        });
        item.siblings().droppable({
            scope: scope,
            accept: function(obj) {
                var handleIndex = obj.find('.sort-handle:first').text();
                return handleIndex != $(this).find('.sort-handle:first').text();
            },
            hoverClass: 'drop-dynamic-row',
            drop: function(event, ui) {
                var dst = $(this);
                var dst_index = parseInt(dst.find('.sort-handle:first').text(), 10);
                var draggable = ui.draggable.find('.sort-handle:first');
                var wrapper = $(draggable.attr('data-sortable-parent'));
                var item = $(draggable.attr('data-sortable-item'));
                var last_index = wrapper.children().length;
                var base_id = draggable.attr("data-base-id");
                var src = item.detach();
                var src_index = parseInt(src.find('.sort-handle:first').text(), 10);
                if (dst_index == last_index) {
                    wrapper.append(src);
                }
                else if(src_index < dst_index) {
                    src.insertAfter(dst);
                }
                else {
                    src.insertBefore(dst);
                }
                wrapper.children().each(function(i,e) {
                    var element = $(e);
                    dynamic_list_update_all_attributes(element, base_id, i);
                });
                wrapper.trigger('dynamic-list.ordered');
            }
        });
    });

    /* Activate dynamic tables (rows can be added and removed) */
    $('body').on('click', '.table-dynamic tbody [href="#add"]', function(event) {
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
                table = tbody.closest('table');
                var id = '#' + table.attr('id') + 'Empty';
                if ($(id).length) {
                    $(id).addClass('hidden');
                }
                tbody.children(':not(.hidden)').find('[href="#delete"]').removeClass('hidden');
            }
            row_new.trigger('admin.added');
            /* Trigger SELECT change event to inherit additional triggers */ 
            row_new.find('select[name$=".type"]').trigger('change');
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
        var sibling = that.data('sibling');
        var section = $('#section');
        var loader = section.prev('.loader');
        if (sibling)
            sibling = that.closest(sibling);
        else
            sibling = that.parent().next();
        var menu = sibling.find('[data-toggle="dropdown"]');
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
        if (menu.length)
            menu.dropdown('toggle'); // close dropdown menu

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
                    });
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
        bindExportCSV();
        FingerbankSearch.setup();
        setupObfuscatedTextHover('.pf-obfuscated-text + button');

        // If the section includes a dynamic sidenav section, move it to the sidenav row
        var sidenav = $('.sidenav-fluid .row-fluid').first();
        $('#section').find('.sidenav-section').each(function() {
            if (this.id && sidenav.find('#' + this.id).length > 0)
                // Section is already there; show it
                sidenav.find('#' + this.id).removeClass('hide');
            else {
                // Append section
                $(this).detach().appendTo(sidenav).removeClass('hide');
            }
        });

        $('[data-pf-toggle="password"]').on('mouseenter focus', function(event) {
            event.currentTarget.removeAttribute('readonly');
        });
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

    $('#checkup_task_toggle').click(function (e) {
        e.preventDefault();
        $( ".checkup_results" ).remove();
        $('<li class="checkup_results disabled"><div class="text-center"><i class="icon-spin icon-circle-o-notch"></i></div></li>').insertAfter($(this).parent());
        $.get("/admin/checkup", function(data){
            var results = $(".checkup_results");
            var li;
            results.html('<a href="#" disabled>Result(s):</a>');
            if(data.items.problems.length > 0){
                for(var i in data.items.problems){
                    li = $('<li class="checkup_results disabled"><a href="#" disabled>'+data.items.problems[i].severity+' : '+data.items.problems[i].message+'</a></li>');
                    li.insertAfter(results);
                }
            } else {
                li = $('<li class="checkup_results disabled"><a href="#" disabled>No problem detected!</a></li>');
                li.insertAfter(results);
            }
        });
        return false;
    });

    $('#fixpermissions_task_toggle').click(function (e) {
        e.preventDefault();
        $( ".fixpermissions_results" ).remove();
        $('<li class="fixpermissions_results disabled"><div class="text-center"><i class="icon-spin icon-circle-o-notch"></i></div></li>').insertAfter($(this).parent());
        $.get("/admin/fixpermissions", function(data){
            var results = $(".fixpermissions_results");
            var li;
            results.html('<a href="#" disabled>Result(s):</a>');
            li = $('<li class="fixpermissions_results disabled"><a href="" disabled>Fixed permissions !</a></li>');
            li.insertAfter(results);
        });
        return false;
    });

    $('#section').on('show', '.modal', function(e) {
      FingerbankSearch.setup();
      setupObfuscatedTextHover('.modal .pf-obfuscated-text + button');
    });

});

function obfuscatedTextHover(element, type, class_remove, class_add) {
    var input = element.prev();
    input.attr('type', type);
    var x_placeholder = input.attr('x-placeholder');
    if (x_placeholder) {
        var placeholder = input.attr('placeholder');
        input.attr('placeholder', x_placeholder);
        input.attr('x-placeholder', placeholder);
    }
    element.find('i').removeClass(class_remove).addClass(class_add);
}

function obfuscatedTextHoverOnEvent(e) {
    obfuscatedTextHover($(this), 'text', 'icon-eye', 'icon-eye-slash');
}

function obfuscatedTextHoverOffEvent(e) {
    obfuscatedTextHover($(this), 'password', 'icon-eye-slash', 'icon-eye');
}

function setupObfuscatedTextHover(selector) {
    var element = $(selector);
    //remove the previous
    element.off("mouseenter.pf mouseleave.pf");
    element.on("mouseenter.pf", obfuscatedTextHoverOnEvent);
    element.on("mouseleave.pf", obfuscatedTextHoverOffEvent);
}

function FingerbankSearch() {

}

FingerbankSearch.prototype.model_stripped = function() {
  var that = this;
  return this.model.split('::Model::')[1].toLowerCase();
};

FingerbankSearch.prototype.search = function(query, process) {
  var that = this;
  var path = this.model_stripped();
  $.ajax({
      type: 'POST',
      url: '/config/fingerbank/'+path+'/typeahead_search',
      headers: {
          Accept: 'application/json',
      },
      data: {
          'json': 1,
          'query': query,
          'model': this.model,
      },
      success: function(data) {
          var results = $.map(data.items, function(i) {
              return i.display;
          });
          that.results = data.items;
          var input = that.typeahead_field;
          var control = input.closest('.control-group');
          if (results.length === 0)
              control.addClass('error');
          else
              control.removeClass('error');
          process(results);
      }
  });
};

FingerbankSearch.setup = function() {
  $('.fingerbank-type-ahead').doOnce('.fingerbank-type-ahead', function(){ 
      var o = this;

      // Creating a new scope since we are in a loop
      (function() {
        var search = new FingerbankSearch();
        search.typeahead_field = $(o);
        // We prevent the browser autocompletion
        search.typeahead_field.attr('autocomplete', "off");
        search.typeahead_btn = $($(o).attr('data-btn'));
        search.model = $(o).attr('data-type-ahead-for');
        search.add_to = $('#'+$(o).attr('data-add-to'));
        search.add_action = $(o).attr('data-add-action');
        $(o).typeahead({
          source: $.proxy(search.search, search),
          minLength: 2,
          items: 11,
          matcher: function(item) { return true; }
        });
        search.typeahead_btn.click(function(e) {
          e.preventDefault();
          var id;
          var display;
          $.each(search.results, function(){
            if(this.display == search.typeahead_field.val()){
              id = this.id;
              display = this.display;
            }
          });
          if (search.add_action) {
            if (search.add_action == 'security_eventsView.add_fingerbank_trigger')
              security_eventsView.add_fingerbank_trigger(search, id, display);
            else
              console.warn("Unhandled add-action \"" + search.add_action + "\"");
          }
          else {
            if(display !== undefined) {
                search.add_to.append('<option selected="selected" value="'+id+'">'+display+'</option>');
                search.add_to.trigger("chosen:updated");
            }
          }
          search.typeahead_field.val('');
          return false;      
        });
      })();
  });
};
