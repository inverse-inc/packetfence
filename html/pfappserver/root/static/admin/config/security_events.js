/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready

    /* Show a security_event from the received HTML */
    function showSecurityEvent(data) {
        var modal = $('#modalSecurityEvent');
        modal.empty();
        modal.append(data);
        modal.find('.switch').bootstrapSwitch();
        modal.find('.chzn-select').chosen({inherit_select_classes: true, width: ''});
        modal.find('.chzn-deselect').chosen({allow_single_deselect: true, width: ''});
        modal.one('shown', function() {
            var data = modal.find('.event_triggers').first()[0];
            security_eventsView.event_triggers = JSON.parse(data.textContent || data.innerHTML);
            $('#actions').trigger('change');
        });
        $('.trigger option').each(function(elem){
          var jthis = $(this);
          var infos = jthis.val().split('::');
          if(infos[0].toLowerCase() == "accounting") {
            var new_value = security_eventsView.prettify_accounting(infos[0], infos[1]);
            jthis.html(new_value);
            jthis.closest('select').trigger("chosen:updated");
          }
        });
        modal.modal('show');
    }

    /* Show a security_event */
    $('#section').on('click', '[href*="#modalSecurityEvent"]', function(event) {
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
                showSecurityEvent(data);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                $("body,html").animate({scrollTop:0}, 'fast');
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Create a security_event */
    $('#section').on('click', '#createSecurityEvent', function(event) {
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
                showSecurityEvent(data);
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    $('#section').on('change', '#viewTriggers select', function(){
      security_eventsView.recompute_triggers();
    });

    /* Delete a security_event */
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
        var modal = $('#deleteSecurityEvent');
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
                    if (table.find('tbody tr').length === 0) {
                        // No more security_events
                        table.remove();
                        $('#noSecurityEvent').removeClass('hidden');
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

        // Show/hide the user_mail_message field if 'email_user' is add/remove
        command_group = $('#user_mail_message').closest('.control-group');
        if ($.inArray('email_user', actions) < 0)
            command_group.fadeOut('fast');
        else
            command_group.fadeIn('fast');

        // Show/hide the user_mail_message field if 'email_user' is add/remove
        command_group = $('#access_duration').closest('.control-group');
        if ($.inArray('autoreg', actions) < 0)
            command_group.fadeOut('fast');
        else
            command_group.fadeIn('fast');

    });

    $('body').on('switch-change', '#security_events .switch', function(event, value) {
        event.preventDefault();
        var t = $(event.target);
        if (t.attr('processing')) {
            return;
        }
        t.attr('processing','processing');
        var href = t.attr('data-href');
        var toggle = value.value ? 'yes' : 'no';
        href = href.replace(/enabled$/, toggle);
        $.ajax({
            type: 'POST',
            url: href,
            data: ''
        }).always(function() {
            t.attr('processing', null);
        }).done(function(data) {
            showSuccess($('#section h2'), data.status_msg);
        }).fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
    });


    /* Modal Editor: save a security_event */
    $('body').on('submit', 'form[name="security_event"]', function(event) {
        var form = $(this),
        btn = form.find('.btn-primary'),
        modal = $('#modalSecurityEvent'),
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
      var val = this.$menu.find('.active').data('item');
      this.$element
        .val(this.updater(val))
        .change();
      return this.hide();
    };

    $.fn.typeahead.Constructor.prototype.render = function (items) {
      var that = this;

      items = $(items).map(function (i, item) {
        i = $(that.options.item).data('item', item);
        i.find('a').html(that.highlighter(item));
        return i[0];
      });

      items.first().addClass('active');
      this.$menu.html(items);
      return this;
    };

    /* Modal Editor: remove a trigger */
    $('body').on('click', '[href="#deleteTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        jthis.closest('.control-group').remove();
        if(!$('#viewTriggers').find('select').length){
          $('#noTrigger').removeClass('hide');
        }
        security_eventsView.recompute_triggers();
        return false;
    });

    /* Modal Editor: add a combined trigger */
    $('body').on('click', '[href="#addTrigger"]', function(event) {
        event.preventDefault();
        var jthis = $(event.target);
        $('#viewTriggers').slideUp(function(){
          $('#editedTrigger').html(SecurityEventsView.add_combined_trigger_form());
          security_eventsView.previous_trigger_options = $('#editedTrigger .triggerButtons').html();
          $('#editedTrigger .triggerButtons').html('<a href="#backEditTrigger" class="pull-left btn btn-default"><i class="icon  icon-chevron-left"></i></a>');
          $('#editedTrigger .chzn-select').chosen({inherit_select_classes: true, width: ''});
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
          security_eventsView.previous_trigger_options = $('#editedTrigger .triggerButtons').html();
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
            $('#noTrigger').addClass('hide');
            triggers.find('.triggerButtons').html(security_eventsView.previous_trigger_options);
            triggers.appendTo('#viewTriggers');
          }
          $('#editedTrigger').html('');
          $('#viewTriggers').slideDown();
        });
        
        security_eventsView.recompute_triggers();
        return false;
    });

    /* Modal Editor: add a trigger to a combined trigger */
    $('body').on('click', '#add_trigger_part', function(event) {
        event.preventDefault();
        var tid =  $('#tid');
        var id = tid.val();
        var type_select = $('#trigger_type').find(':selected');
        var type = type_select.val();

        if(type === '') return false;
  
        var type_name = type_select.text();
        var value = type + "::" + id;
        var value_pretty = type_name + " : " + id;
        security_eventsView.append_trigger(value, value_pretty);
    });

    $('body').on('click', '.add_accounting_trigger', function(event){
      event.preventDefault();
      var trigger_direction = $('#accounting_widget_direction').find(':selected').val();    
      var trigger_amount = $('#accounting_widget_amount').val();    
      var trigger_unit = $('#accounting_widget_unit').find(':selected').val();    
      var trigger_window = $('#accounting_widget_window').find(':selected').val();    
      var tid = trigger_direction+trigger_amount+trigger_unit+trigger_window;
      var trigger = "accounting::"+tid;
      security_eventsView.append_trigger(trigger, security_eventsView.prettify_accounting("accounting",tid));
    });

    /* Modal Editor: add a trigger to a combined trigger from a widget */
    $('body').on('click', '.add_trigger_part', function(event) {
        event.preventDefault();
        event.stopPropagation();
        var tid =  $(this).closest('.controls').find('select').find(':selected');
        var id = tid.val();
        var type_select = $('#trigger_type').find(':selected');
        var type = type_select.val();
        var type_name = type_select.html();
        var value = type + "::" + id;
        var value_pretty = type_name + " : " + tid.html();
        security_eventsView.append_trigger(value, value_pretty);
    });

    
    $('body').on('click', '#security_eventSubmit', function(event) {
        event.preventDefault();
        $('#editTrigger .control-group select').not('#trigger_type').not('.trigger_widget_select').appendTo('#viewTriggers');
        security_eventsView.recompute_triggers();
        $('[name="security_event"]').submit();
        return false;
    });

    $('body').on('change', '#trigger_type', function(){
        var type = $('#trigger_type option:selected').val();
        $('.trigger_widget').slideUp();
        $('.'+type+'_triggers').slideDown();
    });

    $('body').on('click', '.trigger_widget a', function(){
        var modal = $('#modalSecurityEvent');
        modal.modal('hide');
        window.location = $(this).attr('href'); 
    });


});

var SecurityEventsView = function(){};

SecurityEventsView.prototype.recompute_triggers = function() {
  var grouped = {};
  $('#viewTriggers select').find(':selected').each(function(){
      var option = $(this);
      var select = option.closest('select');
      select.uniqueId();
      if(!grouped[select.attr('id')]){
        grouped[select.attr('id')] = [];
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
      trigger = grouped[key][0];
    }
    triggers.push(trigger);
  }

  $('#trigger').val(triggers.join());

};

SecurityEventsView.add_combined_trigger_form = function(){
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
  '</div>'];

  return form.join(' ');
};

SecurityEventsView.prototype.prettify_accounting = function(type, value) {
  var lc_type = type.toLowerCase();
  var lc_value = value.toLowerCase();
  var lc_trigger = lc_type+"::"+lc_value;
  var pretty;
  if(lc_value == "bandwidthexpired") pretty = "Bandwidth expired";
  else if(lc_value == "timeexpired") pretty = "Time expired";
  else {
    var rx = /^(TOT|IN|OUT)([0-9]+)(B|KB|MB|GB|TB)([DWMY])$/;
    var results = rx.exec(value);
    var direction = results[1];
    var amount = results[2];
    var unit = results[3];
    var timeframe = results[4];
    pretty = "";

    if(direction == "TOT") pretty += "Total traffic over "+amount+" "+unit+" ";
    else if(direction == "IN") pretty += "Inbound traffic over "+amount+" "+unit+" ";
    else if(direction == "OUT") pretty += "Outbound traffic over "+amount+" "+unit+" ";

    if(timeframe == "D") pretty += "per day";
    else if(timeframe == "W") pretty += "per week";
    else if(timeframe == "M") pretty += "per month";
    else if(timeframe == "Y") pretty += "per year";
  }
  return pretty;
};

SecurityEventsView.prototype.append_trigger = function(value,value_pretty){
  var that = this;
  if(!value_pretty) value_pretty = value;

  var error = false;
  var select = $('#editedTrigger select').first();
  if(that.event_triggers.indexOf(value.split('::')[0].toLowerCase()) > -1){
    select.find('option:selected').each(function(){
      var data = $(this).val().split('::');
      if(that.event_triggers.indexOf(data[0].toLowerCase()) > -1){
          error = $(this).html();
      }
    });
  }

  if(error) {
    showError($('#viewTriggers'), "There is already an evenemential trigger defined ("+error+"). Only one is allowed per combined trigger.");
    return;
  }

  var last = true;
  select.find('option').each(function() {
      if ($(this).val() > value) {
          $('<option value="' + value + '" selected="selected">' + value_pretty + '</option>').insertBefore(this);
          last = false;
          return false;
      }
  });
  if (last)
      select.append('<option value="' + value + '" selected="selected">' + value_pretty + '</option>');
  select.trigger("chosen:updated");

};

SecurityEventsView.prototype.add_fingerbank_trigger = function(search, id, display){
  var that = this;
  security_eventsView.append_trigger(search.model_stripped()+"::"+id, search.model_stripped() + " " + display);
};

var security_eventsView = new SecurityEventsView();
