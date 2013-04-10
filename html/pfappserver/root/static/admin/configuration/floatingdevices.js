$(function() { // DOM ready
    var floatingdevices = new FloatingDevices();
    var view = new FloatingDeviceView({ floatingdevices: floatingdevices, parent: $('#section') });
});

/*
 * The FloatingDevices class defines the operations available from the controller.
 */
var FloatingDevices = function() {
};

FloatingDevices.prototype.get = function(options) {
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

FloatingDevices.prototype.post = function(options) {
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
 * The FloatingDeviceView class defines the DOM operations from the Web interface.
 */
var FloatingDeviceView = function(options) {
    var that = this;
    this.parent = options.parent;
    this.floatingdevices = options.floatingdevices;

    // Display the floatingdevice in a modal
    var read = $.proxy(this.readFloatingDevice, this);
    options.parent.on('click', '#floatingdevices [href$="/read"], #createFloatingDevice', read);

    // Save the modifications from the modal
    var update = $.proxy(this.updateFloatingDevice, this);
    options.parent.on('submit', 'form[name="modalFloatingDevice"]', update);

    // Delete the floatingdevice
    var delete_s = $.proxy(this.deleteFloatingDevice, this);
    options.parent.on('click', '#floatingdevices [href$="/delete"]', delete_s);

    // Show the tagged VLANs field when 'trunk port' is checked
    options.parent.on('change', 'form[name="modalFloatingDevice"] input[name="trunkPort"]', this.toggleTaggedVlan);

    // Initialize the tagged VLANs fields when displaying a floating device
    options.parent.on('show', '#modalFloatingDevice', function(e) {
        var checkbox = $('form[name="modalFloatingDevice"] input[name="trunkPort"]').first();
        $.proxy(that.toggleTaggedVlan, checkbox)(e);
    });
};

FloatingDeviceView.prototype.readFloatingDevice = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalFloatingDevice');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    this.floatingdevices.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.modal({ shown: true });
            modal.one('shown', function() {
                modal.find(':input:visible').first().focus();
            });
        },
        errorSibling: section.find('h2').first()
    });
};

FloatingDeviceView.prototype.toggleTaggedVlan = function(e) {
    var checkbox = $(this);
    var taggedVlan = checkbox.closest('form').find('input[name="taggedVlan"]').first();

    if (checkbox.is(':checked'))
        taggedVlan.removeAttr('disabled');
    else
        taggedVlan.attr('disabled', 1);
};

FloatingDeviceView.prototype.updateFloatingDevice = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.floatingdevices.post({
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

FloatingDeviceView.prototype.list = function() {
    this.floatingdevices.get({
        url: '/configuration/floatingdevice/list',
        success: function(data) {
            var table = $('#floatingdevices');
            table.html(data);
        },
        errorSibling: $('#floatingdevices')
    });
};

FloatingDeviceView.prototype.deleteFloatingDevice = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    this.floatingdevices.get({
        url: url,
        success: function(data) {
            showSuccess($('#floatingdevices'), data.status_msg);
            row.fadeOut('slow', function() { $(this).remove(); });
        },
        errorSibling: $('#floatingdevices')
    });
};
