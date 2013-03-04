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
    $.ajax({ url: options.url })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Switches.prototype.post = function(options) {
    $.ajax({
        url: options.url,
        type: 'POST',
        data: options.data
    })
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

/*
 * The SwitchView class defines the DOM operations from the Web interface.
 */
var SwitchView = function(options) {
    this.switches = options.switches;
    this.disableToggle = false;

    var read = $.proxy(this.readSwitch, this);
    options.parent.on('click', '#switches [href$="/read"], #createSwitch', read);

    var update = $.proxy(this.updateSwitch, this);
    options.parent.on('submit', 'form[name="modalSwitch"]', update);

    var delete_s = $.proxy(this.deleteSwitch, this);
    options.parent.on('click', '#switches [href$="/delete"]', delete_s);
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

SwitchView.prototype.updateSwitch = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var modal = $('#modalSwitch');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);

        this.switches.post({
            url: form.attr('action'),
            data: form.serialize(),
            success: function(data) {
                modal.modal('toggle');
                showSuccess($('#switches'), data.status_msg);
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
