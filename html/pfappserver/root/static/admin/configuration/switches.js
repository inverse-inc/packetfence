$(function() { // DOM ready
    var switches = new Switches();
    var view = new SwitchView({ switches: switches, parent: $('#section') });
});

/*
 * The Switches class defines the operations available from the controller.
 */
var Switches = function() {
};

Switches.prototype.get = function(options) {
    $.ajax({
        url: options.url
    })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError(options.errorSibling, status_msg);
        });
};

Switches.prototype.post = function(options) {
    $.ajax({
        url: options.url,
        type: 'POST',
        data: options.data
    })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError(options.errorSibling, status_msg);
        });
};

/*
 * The SwitchView class defines the DOM operations from the Web interface.
 */
var SwitchView = function(options) {
    var that = this;
    this.parent = options.parent;
    this.switches = options.switches;
    this.disableToggle = false;

    // Display the switch in a modal
    var read = $.proxy(this.readSwitch, this);
    options.parent.on('click', '#switches [href$="/read"], #createSwitch', read);

    // Save the modifications from the modal
    var update = $.proxy(this.updateSwitch, this);
    options.parent.on('submit', 'form[name="modalSwitch"]', update);

    // Delete the switch
    var delete_s = $.proxy(this.deleteSwitch, this);
    options.parent.on('click', '#switches [href$="/delete"]', delete_s);

    // Disable the uplinks field when 'dynamic uplinks' is checked
    options.parent.on('change', 'form[name="modalSwitch"] input[name="uplink_dynamic"]', this.changeDynamicUplinks);

    // Initial creation of an inline trigger when no trigger is defined
    options.parent.on('click', '#triggerInlineEmpty [href="#add"]', this.addInlineTrigger);

    // Initialize the inline trigger fields when displaying a switch
    options.parent.on('show', '#modalSwitch', function(e) {
        $('#triggerInline tr:not(.hidden) select').each(function() {
            that.updateInlineTrigger($(this));
        });
    });

    // Update the trigger fields when adding a new trigger
    options.parent.on('admin.added', '#triggerInline tr', function(e) {
        var attribute = $(this).find('select').first();
        that.updateInlineTrigger(attribute);
    });

    // Update the trigger fields when changing a trigger
    options.parent.on('change', '#triggerInline select', function(e) {
        that.updateInlineTrigger($(this));
    });
};

SwitchView.prototype.readSwitch = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalSwitch');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    this.switches.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.find('.chzn-select').chosen({allow_single_deselect: true});
            modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
            modal.modal({ shown: true });
            modal.one('shown', function() {
                modal.find(':input:visible').first().focus();
            });
        },
        errorSibling: section.find('h2').first()
    });
};

SwitchView.prototype.changeDynamicUplinks = function(e) {
    var checkbox = $(this);
    var uplinks = checkbox.closest('form').find('input[name="uplink"]').first();

    if (checkbox.is(':checked'))
        uplinks.attr('disabled', 1);
    else
        uplinks.removeAttr('disabled');
};

SwitchView.prototype.addInlineTrigger = function(e) {
    var tbody = $('#triggerInline').children('tbody');
    var row_model = tbody.children('.hidden').first();
    if (row_model) {
        $('#triggerInlineEmpty').addClass('hidden');
        var row_new = row_model.clone();
        row_new.removeClass('hidden');
        row_new.insertBefore(row_model);
        row_new.trigger('admin.added');
    }
    return false;
};

SwitchView.prototype.updateInlineTrigger = function(attribute) {
    var trigger = attribute.find(':selected').val();
    var value = attribute.next();

    if (trigger != value.attr('data-trigger')) {
        value.attr('disabled', 1);

        var value_new = $('#' + trigger + '_trigger').clone();
        value_new.attr('id', value.attr('id'));
        value_new.attr('name', value.attr('name'));
        value_new.insertBefore(value);

        if (!value.attr('data-trigger')) {
            // Preserve values of an existing condition
            value_new.val(value.val());
        }

        // Remove previous fields
        value.remove();

        // Remember the data type
        value_new.attr('data-trigger', trigger);
    }
};

SwitchView.prototype.updateSwitch = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.switches.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
            },
            success: function(data) {
                modal.modal('toggle');
                showSuccess(that.parent.find('.table.items').first(), data.status_msg);
                that.list();
            },
            errorSibling: modal_body.children().first()
        });
    }
};

SwitchView.prototype.list = function() {
    this.switches.get({
        url: '/configuration/switch/list',
        success: function(data) {
            var table = $('#switches');
            table.html(data);
        },
        errorSibling: $('#switches')
    });
};

SwitchView.prototype.deleteSwitch = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    this.switches.get({
        url: url,
        success: function(data) {
            showSuccess($('#switches'), data.status_msg);
            row.fadeOut('slow', function() { $(this).remove(); });
        },
        errorSibling: $('#switches')
    });
};
