$(function() { // DOM ready

    function getTrigger(query, process) {
        var input = $('#violationTriggers [data-provide="typeahead"]');
        var trigger_type = $('#trigger_type');
        var type = trigger_type.val();
        //console.log(trigger_type);
        var control = input.closest('.control-group');
        $.ajax('/trigger/search/' + type + "/" + query)
            .done(function(data) {
                process(data.items);
            })
            .fail(function(jqXHR) {
                control.addClass('error');
            });
    }

    /* Show a violation from the received HTML */
    function showViolation(data) {
        var modal = $('#modalViolation');
        modal.empty();
        modal.append(data);
        modal.find('.switch').bootstrapSwitch();
        modal.find('.chzn-select').chosen();
        modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
        modal.one('shown', function() {
            $('#actions').trigger('change');
        });
        modal.find('[data-provide="typeahead"]').typeahead({
            minLength: 2,
            items: 11,
            source: getTrigger,
            matcher: function(item) { return true; },
            updater: function(item) { return item.value; },
            sorter: function(items) { return items; },
            highlighter: function (item) {
              var query = this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, '\\$&')
              return item.display.replace(new RegExp('(' + query + ')', 'ig'), function ($1, match) {
                return '<strong>' + match + '</strong>'
              })
            }
        });
        modal.modal('show');
    }

    /* Show a violation */
    $('#section').on('click', '[href*="#modalViolation"]', function(event) {
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(url)
            .always(function(){
                loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                showViolation(data);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                $("body,html").animate({scrollTop:0}, 'fast');
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Create a violation */
    $('#section').on('click', '#createViolation', function(event) {
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(url)
            .always(function(){
                loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                showViolation(data);
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Delete a violation */
    $('#section').on('click', '[href*="/delete"]', function(e) {
        e.preventDefault();
        if ($(this).hasClass('disabled'))
            return false;
        var link = $(this);
        var url = link.attr('href');
        var row = link.closest('tr');
        var cells = row.find('td');
        var name = $(cells[1]).text();
        if (!name) name = $(cells[0]).text();
        var modal = $('#deleteViolation');
        var confirm_link = modal.find('a.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal('show');
        confirm_link.off('click');
        confirm_link.click(function(e) {
            e.preventDefault();
            confirm_link.button('loading');
            $.ajax(url)
                .always(function() {
                    modal.modal('hide');
                    confirm_link.button('reset');
                })
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    if (table.find('tbody tr').length == 0) {
                        // No more violations
                        table.remove();
                        $('#noViolation').removeClass('hidden');
                    }
                })
                .fail(function(jqXHR) {
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section h2'), status_msg);
                    confirm_link.button('reset');
                });
        });

        return false;
    });

    /* Modal Editor: add/remove an action */
    $('body').on('change', '#actions', function(event) {
        var actions = $(this).val();

        // Show/hide the vclose field if 'close' is add/remove
        var vclose_group = $('#vclose').closest('.control-group');
        if ($.inArray('close', actions) < 0)
            vclose_group.fadeOut('fast');
        else
            vclose_group.fadeIn('fast');

        // Show/hide the target_category field if 'role' is add/remove
        var role_group = $('#target_category').closest('.control-group');
        if ($.inArray('role', actions) < 0)
            role_group.fadeOut('fast');
        else
            role_group.fadeIn('fast');
    });

    /* Modal Editor: add a trigger */
    $('body').on('click', '[href="#addTrigger"]', function(event) {
        event.preventDefault();
        var tid =  $('#tid');
        var id = tid.val();
        var type_select = $('#trigger_type').find(':selected');
        var type = type_select.val();
        var type_name = type_select.text();
        var value = type + "::" + id;
        var name = type_name + "::" + id;
        var select = $('#trigger');
        var last = true;
        tid.val('');
        select.find('option').each(function() {
            if ($(this).val() > value) {
                $('<option value="' + value + '" selected="selected">' + name + '</option>').insertBefore(this);
                last = false;
                return false;
            }
        });
        if (last)
            select.append('<option value="' + value + '" selected="selected">' + name + '</option>');
        select.trigger("liszt:updated");
    });

    /* Modal Editor: save a violation */
    $('body').on('submit', 'form[name="violation"]', function(event) {
        var form = $(this),
        btn = form.find('.btn-primary'),
        modal = $('#modalViolation'),
        modal_body = modal.find('.modal-body'),
        valid = isFormValid(form);

        if (valid) {
            resetAlert(modal_body);
            btn.button('loading');
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).always(function() {
                btn.button('reset');
            }).done(function() {
                modal.on('hidden', function() {
                    // Refresh the section
                    $(window).hashchange();
                });
                modal.modal('hide');
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });

    $.fn.typeahead.Constructor.prototype.select = function () {
      var val = this.$menu.find('.active').data('item')
      this.$element
        .val(this.updater(val))
        .change()
      return this.hide()
    };

    $.fn.typeahead.Constructor.prototype.render = function (items) {
      var that = this

      items = $(items).map(function (i, item) {
        i = $(that.options.item).data('item', item)
        i.find('a').html(that.highlighter(item))
        return i[0]
      })

      items.first().addClass('active')
      this.$menu.html(items)
      return this
    };

});
