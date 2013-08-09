$(function() { // DOM ready
    var adminroles = new AdminRoles();
    var view = new AdminRolesView({ adminroles: adminroles, parent: $('#section') });
});

/*
 * The AdminRoles class defines the operations available from the controller.
 */
var AdminRoles = function() {
};

AdminRoles.prototype.get = function(options) {
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

AdminRoles.prototype.post = function(options) {
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
 * The AdminRolesView class defines the DOM operations from the Web interface.
 */
var AdminRolesView = function(options) {
    var that = this;
    this.parent = options.parent;
    this.adminroles = options.adminroles;

    // Display the adminroles in a modal
    var read = $.proxy(this.readAdminRoles, this);
    options.parent.on('click', '#adminroles [href$="/read"], #adminroles [href$="/clone"], #createAdminRoles', read);

    // Save the modifications from the modal
    var update = $.proxy(this.updateAdminRoles, this);
    options.parent.on('submit', 'form[name="modalAdminRoles"]', update);

    // Delete the adminroles
    var delete_s = $.proxy(this.deleteAdminRoles, this);
    options.parent.on('click', '#adminroles [href$="/delete"]', delete_s);

};

AdminRolesView.prototype.readAdminRoles = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalAdminRoles');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    this.adminroles.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.one('shown', function() {
                modal.find(':input:visible').first().focus();
            });
            modal.modal({ shown: true });
        },
        errorSibling: section.find('h2').first()
    });
};

AdminRolesView.prototype.updateAdminRoles = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.adminroles.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
            },
            success: function(data) {
                modal.on('hidden', function() {
                    $('#noRole:visible').addClass('hidden');
                    $('#adminroles').replaceWith(data);
                });
                modal.modal('hide');
            },
            errorSibling: modal_body.children().first()
        });
    }
};

AdminRolesView.prototype.deleteAdminRoles = function(e) {
    e.preventDefault();

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    this.adminroles.get({
        url: url,
        success: function(data) {
            var table = $('#adminroles');
            showSuccess(table, data.status_msg);
            row.remove();
            if (table.find('tbody tr').length == 0) {
                // No more filters
                table.addClass('hidden');
                $('#noRole').removeClass('hidden');
            }
        },
        errorSibling: $('#adminroles')
    });
};
