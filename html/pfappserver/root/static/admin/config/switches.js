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
    options.parent.on('click', '#switches [href$="/read"], #switches [href$="/clone"], .createSwitch', read);

    // Save the modifications from the modal
    var update = $.proxy(this.updateSwitch, this);
    options.parent.on('submit', 'form[name="modalSwitch"]', update);

    // Delete the switch
    var delete_s = $.proxy(this.deleteConfirm, this);
    options.parent.on('click', '#switches [href$="/delete"]', delete_s);

    // Remove the group from the switch
    var remove_group = $.proxy(this.removeGroup, this);
    options.parent.on('click', 'form[name="modalSwitch"] [href$="/remove_group"]', remove_group);

    // Add a group to the switch group
    var add_to_group = $.proxy(this.addToGroup, this);
    options.parent.on('click', 'form[name="modalSwitch"] #addNewMember', add_to_group);

    // Disable the uplinks field when 'dynamic uplinks' is checked
    options.parent.on('change', 'form[name="modalSwitch"] input[name="uplink_dynamic"]', this.changeDynamicUplinks);

    // Disable the mapping fields for inactive modes (VLAN and/or roles)
    options.parent.on('change', 'form[name="modalSwitch"] input[type="checkbox"][name*="Map"]', this.changeRoleMapping);

    // Initial creation of an inline trigger when no trigger is defined
    options.parent.on('click', '#inlineTriggerEmpty [href="#add"]', this.addInlineTrigger);

    // Initialize the inline trigger fields when displaying a switch
    options.parent.on('show', '#modalSwitch', function(e) {
        $('#inlineTrigger tr:not(.hidden) select').each(function() {
            that.updateInlineTrigger($(this));
        });

        $('[data-provide="typeahead"]').typeahead({
            source: $.proxy(that.searchSwitch, that),
            minLength: 2,
            items: 11,
            matcher: function(item) { return true; }
        });
    });

    // Update the trigger fields when adding a new trigger
    options.parent.on('admin.added', '#inlineTrigger tr', function(e) {
        var attribute = $(this).find('select').first();
        that.updateInlineTrigger(attribute);
    });

    // Update the trigger fields when changing a trigger
    options.parent.on('change', '#inlineTrigger select', function(e) {
        that.updateInlineTrigger($(this));
    });

    // pagination the switch
    var pagination = $.proxy(this.pagination, this);
    options.parent.on('click', '#switches [href*="/list"]', pagination);

    // submit search
    options.parent.on('submit', '#switches #search', $.proxy(this.submitSearch, this));

    // reset search
    options.parent.on('reset', '#switches #search', $.proxy(this.resetSearch, this));

    // pagination search
    options.parent.on('click', '#switches [href*="/switch/search"]', $.proxy(this.searchPagination, this));


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
    $('.chzn-drop').remove(); // fixes a chzn bug with optgroups
    this.switches.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.find('.chzn-select').chosen();
            modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
            modal.one('shown', function() {
                var checkbox;
                modal.find(':input:visible').first().focus();
                // Update state of uplinks field
                checkbox = $('form[name="modalSwitch"] input[name="uplink_dynamic"]');
                that.changeDynamicUplinks.call(checkbox);
                // Update state of mapping fields
                checkbox = $('form[name="modalSwitch"] input[type="checkbox"][name*="Map"]');
                checkbox.each(function(i) { that.changeRoleMapping.call(this); });
            });
            modal.modal({ shown: true });
        },
        errorSibling: section.find('h2').first()
    });
};

SwitchView.prototype.changeRoleMapping = function(e) {
    var checkbox = $(this);
    var match = /(.+)Map/.exec(checkbox.attr('name'));
    var type = match[1];
    var inputs = $.merge(checkbox.closest('form').find('input[type="text"][name*="'+type+'"]'), checkbox.closest('form').find('textarea[name*="'+type+'"]'));

    if (checkbox.is(':checked'))
        inputs.removeAttr('disabled');
    else
        inputs.attr('disabled', 1);
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
    var tbody = $('#inlineTrigger').children('tbody');
    var row_model = tbody.children('.hidden').first();
    if (row_model) {
        $('#inlineTriggerEmpty').addClass('hidden');
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
    var btn = form.find('.btn-primary');
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        btn.button('loading');
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.switches.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
                btn.button('reset');
            },
            success: function(data) {
                modal.modal('toggle');
                showSuccess(that.parent.find('.table.items').first(), data.status_msg);
                that.refreshTable();
            },
            errorSibling: modal_body.children().first()
        });
    }
};

SwitchView.prototype.addToGroup = function(e) {
    e.preventDefault();

    var that = this;
    var button = $(e.target);
    var newMemberId = $('#newMember').val();
    this.switches.get({
        url: "/config/switch/"+newMemberId+"/add_to_group/"+button.attr('data-group'),
        success: function(data) {
            that.readSwitch({
              preventDefault: function(){},
              target: {
                href: "/config/switchgroup/"+button.attr('data-group')+"/read",
              },
            });
            showSuccess($('#modalSwitch .modal-body').children().first(), data.status_msg);
        },
        errorSibling: $('#modalSwitch .modal-body').children().first(),
    });
}

SwitchView.prototype.removeGroup = function(e) {
    e.preventDefault();

    var that = this;
    var a = $(e.target);
    this.switches.get({
        url: a.attr('href'),
        success: function(data) {
            a.closest('.switchGroupMember').remove();
            if ($('.switchGroupMember').size() == 0){
              $('#switchMembersEmpty').closest('tr').removeClass('hidden');
            }
            showSuccess($('#modalSwitch .modal-body').children().first(), data.status_msg);
        },
        errorSibling: $('#modalSwitch .modal-body').children().first(),
    });
};

SwitchView.prototype.list = function() {
    this.switches.get({
        url: '/config/switch/list',
        success: function(data) {
            var table = $('#switches');
            table.html(data);
        },
        errorSibling: $('#switches')
    });
};


SwitchView.prototype.refreshPage = function() {
    var that = this;
    var pagination = $('.pagination').first();
    var formId = pagination.attr('data-from-form') || '#search';
    var form = $(formId);
    var link = pagination.find('li.disabled a[href]').first();
    if(form.length == 0) {
        form = $('#search');
    }
    var columns = $('#columns');
    var href = link.attr("href");
    var section = $('#section');
    var status_container = $("#section").find('h2').first();
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    section.fadeTo('fast', 0.5, function() {
        that.switches.post({
            url: href,
            data: form.serialize() + "&" + columns.serialize(),
            always: function() {
                loader.hide();
                section.fadeTo('fast', 1.0);
            },
            success: function(data) {
                section.html(data);
            },
            errorSibling: status_container
        });
    });
    return false;
};

SwitchView.prototype.refreshTable = function() {
    var that = this;
    var pagination = $('.pagination').first();
    var formId = pagination.attr('data-from-form') || '#search';
    var form = $(formId);
    var link = pagination.find('li.disabled a[href]').first();
    if(form.length == 0) {
        form = $('#search');
    }
    var columns = $('#columns');
    var href = link.attr("href");
    var section = $('#section');
    var status_container = $("#section").find('h2').first();
    var table = $('#switches');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5, function() {
        that.switches.post({
            url: href,
            data: form.serialize() + "&" + columns.serialize(),
            always: function() {
                loader.hide();
                section.fadeTo('fast', 1.0);
            },
            success: function(data) {
                table.html(data);
            },
            errorSibling: status_container
        });
    });
    return false;
};
SwitchView.prototype.pagination = function(e) {
    e.preventDefault();
    var link = $(e.target);
    var url = link.attr('href');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    this.switches.get({
        url: url,
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            var table = $('#switches');
            table.html(data);
        },
        errorSibling: $('#switches')
    });
    return false;
};

SwitchView.prototype.searchPagination = function(e) {
    e.preventDefault();
    var link = $(e.currentTarget);
    var form = $('#search');
    var href = link.attr("href");
    this.refreshListFromForm(href,form);
    return false;
};

SwitchView.prototype.refreshListFromForm = function(href,form) {
    var that = this;
    var section = $('#section');
    $("body,html").animate({scrollTop:0}, 'fast');
    var status_container = $("#section").find('h2').first();
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5, function() {
        that.switches.post({
            url: href,
            data: form.serialize(),
            always: function() {
                loader.hide();
                section.fadeTo('fast', 1.0);
            },
            success: function(data) {
                var table = $('#switches');
                table.html(data);
            },
            errorSibling: status_container
        });
    });
    return false;
};

SwitchView.prototype.submitSearch = function(e) {
    e.preventDefault();
    var that = this;
    var form = $(e.currentTarget);
    var href = form.attr("action");
    this.refreshListFromForm(href,form);
    return false;
};

SwitchView.prototype.resetSearch = function(e) {
    var that = this;
    var section = $('#section');
    $("body,html").animate({scrollTop:0}, 'fast');
    var status_container = $("#section").find('h2').first();
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5, function() {
        that.switches.post({
            url: '/config/switch/list',
            always: function() {
                loader.hide();
                section.fadeTo('fast', 1.0);
            },
            success: function(data) {
                var table = $('#switches');
                table.html(data);
            },
            errorSibling: status_container
        });
    });
    return true;
};

SwitchView.prototype.deleteConfirm = function(e) {
    e.preventDefault();
    var that = this;

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    var modal = $('#deleteSwitch');
    var confirm_link = modal.find('a.btn-primary').first();
    confirm_link.off('click');
    confirm_link.click(function() {
        that.switches.get({
            url: url,
            success: function(data) {
                showSuccess($('#switches'), data.status_msg);
                row.fadeOut('slow', function() { $(this).remove(); });
            },
            always : function() {
                modal.modal('hide');
            },
            errorSibling: $('#switches')
        });
        return false;
    });
    modal.modal({ show: true });
    return false;
};

SwitchView.prototype.searchSwitch = function(query, process){
    this.switches.post({
        url: '/config/switch/search',
        data: {
            'json': 1,
            'all_or_any': 'any',
            'searches.0.name': 'id',
            'searches.0.op': 'like',
            'searches.0.value': query,
        },
        success: function(data) {
            var results = $.map(data.items, function(i) {
                return i.id;
            });
            var input = $('#modalSwitch #newMember');
            var control = input.closest('.control-group');
            if (results.length == 0)
                control.addClass('error');
            else
                control.removeClass('error');
            process(results);
        }
    });
}
