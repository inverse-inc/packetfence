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

    $('#section').on('change', '#viewTriggers select', function(){
      violationsView.recompute_triggers();
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

        // Show/hide the external_command field if 'external' is add/remove
        var command_group = $('#external_command').closest('.control-group');
        if ($.inArray('external', actions) < 0)
            command_group.fadeOut('fast');
        else
            command_group.fadeIn('fast');
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

    /* Modal Editor: remove a trigger */
    $('body').on('click', '[href="#deleteTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        jthis.closest('.control-group').remove()
        if(!$('#viewTriggers').find('select').length){
          $('#noTrigger').show();
        }
        violationsView.recompute_triggers();
        return false;
    });

    /* Modal Editor: add a combined trigger */
    $('body').on('click', '[href="#addTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        $('#viewTriggers').slideUp(function(){
          $('#editedTrigger').html(ViolationsView.add_combined_trigger_form());
          violationsView.previous_trigger_options = $('#editedTrigger .triggerButtons').html();
          $('#editedTrigger .triggerButtons').html('<a href="#backEditTrigger" class="pull-left btn btn-default"><i class="icon  icon-chevron-left"></i></a>');
          $('#editedTrigger .chzn-select').chosen();
          $('#editTrigger').slideDown();
        });
        
        return false;
    });

    /* Modal Editor: edit a trigger */
    $('body').on('click', '[href="#editTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        $('#viewTriggers').slideUp(function(){
          var triggers = jthis.closest('.control-group');
          triggers.appendTo('#editedTrigger');
          violationsView.previous_trigger_options = $('#editedTrigger .triggerButtons').html();
          $('#editedTrigger .triggerButtons').html('<a href="#backEditTrigger" class="pull-left btn btn-default"><i class="icon  icon-chevron-left"></i></a>');
          $('#editTrigger').slideDown();
        });
        
        return false;
    });

    /* Modal Editor: back from edit a trigger */
    $('body').on('click', '[href="#backEditTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        $('#editTrigger').slideUp(function(){
          var triggers = jthis.closest('.control-group');
          if(triggers.find("select option:selected").length){
            $('#noTrigger').hide();
            triggers.find('.triggerButtons').html(violationsView.previous_trigger_options);
            triggers.appendTo('#viewTriggers');
          }
          $('#editedTrigger').html('');
          $('#viewTriggers').slideDown();
        });
        
        violationsView.recompute_triggers();
        return false;
    });

    /* Modal Editor: add a trigger to a combined trigger */
    $('body').on('click', '[href="#addTriggerPart"]', function(event) {
        event.preventDefault();
        var tid =  $('#tid');
        var id = tid.val();
        var type_select = $('#trigger_type').find(':selected');
        var type = type_select.val();
        var type_name = type_select.text();
        var value = type + "::" + id;
        var name = type_name + "::" + id;
        var select = $('#editedTrigger select').first();
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

    
    $('body').on('click', '#violationSubmit', function(event) {
        event.preventDefault();
        $('#editTrigger .control-group select').not('#trigger_type').appendTo('#viewTriggers');
        violationsView.recompute_triggers();
        console.log($('#trigger').val())
        $('[name="violation"]').submit();
        return false;
    });


});

var ViolationsView = function(){}

ViolationsView.prototype.recompute_triggers = function() {
  var grouped = {};
  $('#viewTriggers select').find(':selected').each(function(){
      var option = $(this);
      var select = option.closest('select');
      select.uniqueId();
      if(!grouped[select.attr('id')]){
        grouped[select.attr('id')] = []
      }
      grouped[select.attr('id')].push(option.val());
  });

  var triggers = [];
  for(var key in grouped){
    var trigger;
    if(grouped[key].length > 1){
      trigger = grouped[key].join('&');
      trigger = "("+trigger+")";
    }
    else {
      trigger = grouped[key][0]
    }
    triggers.push(trigger);
  }

  $('#trigger').val(triggers.join());

}

ViolationsView.add_combined_trigger_form = function(){
  var form = [
  '<div class="control-group">',
  '  <span class="triggerButtons">',
  '    <a class="btn pull-left" href="#editTrigger">',
  '      <i class="icon icon-pencil"></i>',
  '    </a>',
  '    <a class="btn btn-danger pull-left" href="#deleteTrigger">',
  '      <i class="icon icon-remove"></i>',
  '    </a>',
  '  </span>',
  '  <select multiple="multiple" class="chzn-select input-xxlarge">',
  '  </select>',
  '</div>']

  return form.join(' ');
}

var violationsView = new ViolationsView();
