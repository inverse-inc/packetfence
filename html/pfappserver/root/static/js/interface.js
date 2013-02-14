/*
 * The Interfaces class defines the operations available from the controller.
 */
var Interfaces = function() {
};

Interfaces.prototype.action = function(options) {
    $.ajax({ url: options.url })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Interfaces.prototype.update = function(options) {
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

Interfaces.prototype.list = function(options) {
    $.ajax({ url: '/interface/list' })
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Interfaces.prototype.toggle = function(options) {
    var action = options.status? "up" : "down";
    var url = ['/interface',
               options.name,
               action];
    $.ajax({ url: url.join('/') })
        .always(options.always)
        .done(options.success)
        .fail(options.error);
};

/*
 * The InterfaceView class defines the DOM operations from the Web interface.
 */
var InterfaceView = function(options) {
    this.interfaces = options.interfaces;
    this.disableToggle = false;

    var read = $.proxy(this.readInterface, this);
    options.parent.on('click', '#interfaces [href$="/read"], #interfaces [href$="/create"]', read);

    var update = $.proxy(this.updateInterface, this);
    options.parent.on('submit', 'form[name="modalEditInterface"], form[name="modalCreateVlan"]', update);

    var delete_p = $.proxy(this.deleteInterface, this);
    options.parent.on('click', '#interfaces [href$="/delete"]', delete_p);

    var toggle = $.proxy(this.toggleInterface, this);
    options.parent.on('switch-change', '#interfaces .switch', toggle);

    var typeChanged = $.proxy(this.typeChanged, this);
    options.parent.on('change', '[name="type"]', typeChanged);
};

InterfaceView.prototype.readInterface = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalEditInterface');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    this.interfaces.action({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
            modal.modal({ shown: true });
            modal.one('shown', function() {
                modal.find(':input:visible').first().focus();
                that.typeChanged();
            });
        },
        errorSibling: section.find('h2').first()
    });
};

InterfaceView.prototype.typeChanged = function(e) {
    var modal = $('#modalEditInterface');
    var type = e? $(e.target) : modal.find('[name="type"]');
    var dns = modal.find('[name="dns"]').closest('.control-group');
    if (type.val() == 'inline')
        dns.show('fast');
    else
        dns.hide('fast');
};

InterfaceView.prototype.updateInterface = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var modal = $('#modalEditInterface');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);

        this.interfaces.update({
            url: form.attr('action'),
            data: form.serialize(),
            success: function(data) {
                modal.modal('toggle');
                showSuccess($('#interfaces table'), data.status_msg);
                that.list();
            },
            errorSibling: modal_body.children().first()
        });
    }
};

InterfaceView.prototype.list = function() {
    this.interfaces.list({
        success: function(data) {
            var table = $('#interfaces table');
            table.html(data);
            table.find('.switch').bootstrapSwitch();
        },
        errorSibling: $('#interfaces table')
    });
};

InterfaceView.prototype.deleteInterface = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    this.interfaces.action({
        url: url,
        success: function(data) {
            showSuccess($('#interfaces table'), data.status_msg);
            row.fadeOut('slow', function() { $(this).remove(); });
        },
        errorSibling: $('#interfaces table')
    });
};

InterfaceView.prototype.toggleInterface = function(e) {
    e.preventDefault();

    // Ignore event if it occurs while processing a toggling
    if (this.disableToggle) return;
    this.disableToggle = true;

    var that = this;
    var btn = $(e.target);
    var name = btn.find('input:checkbox').attr('name');
    var status = btn.bootstrapSwitch('status');
    resetAlert($('#interfaces'));
    this.interfaces.toggle({
        name: name,
        status: status,
        success: function(data) {
            showSuccess($('#interfaces table'), data.status_msg);
            $.each(data.interfaces, function(i, status) {
                if (i !== name)
                    $('input:checkbox[name="'+i+'"]').closest('.switch').bootstrapSwitch('setState', status === "1");
            });
            that.disableToggle = false;
        },
        error: function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError($('#interfaces table'), status_msg);
            btn.bootstrapSwitch('setState', !status, true);
            that.disableToggle = false;
        }
    });
};