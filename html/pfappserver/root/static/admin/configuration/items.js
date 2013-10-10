$(function() { // DOM ready
    var items = new Items();
    var view = new ItemView({ items: items, parent: $('#section') });
});

/*
 * The Items class defines the operations available from the controller.
 */
var Items = function() {
};

Items.prototype.id = "#items";

Items.prototype.get = function(options) {
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

Items.prototype.post = function(options) {
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
 * The ItemView class defines the DOM operations from the Web interface.
 */
var ItemView = function(options) {
    this.setupItem(options);
};


ItemView.prototype.setupItem = function(options) {
    var that = this;
    this.parent = options.parent;
    var items = options.items
    this.items = items;
    this.disableToggle = false;
    var id = items.id;

    // Display the switch in a modal
    var read = $.proxy(this.readItem, this);
    options.parent.on('click', id + ' [href$="/read"], ' + id + ' [href$="/clone"], #createItem', read);

    // Save the modifications from the modal
    var update = $.proxy(this.updateItem, this);
    options.parent.on('submit', 'form[name="modalItem"]', update);

    // Delete the switch
    var delete_item = $.proxy(this.deleteItem, this);
    options.parent.on('click', id + ' [href$="/delete"]', delete_item);
};


ItemView.prototype.readItem = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalItem');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    $('.chzn-drop').remove(); // fixes a chzn bug with optgroups
    this.items.get({
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
                modal.find(':input:visible').first().focus();
            });
            modal.modal({ shown: true });
        },
        errorSibling: section.find('h2').first()
    });
};

ItemView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var table = $(this.items.id);
    var btn = form.find('.btn-primary');
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        btn.button('loading');
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
                btn.button('reset');
            },
            success: function(data) {
                modal.modal('toggle');
                showSuccess(table, data.status_msg);
                that.list();
            },
            errorSibling: modal_body.children().first()
        });
    }
};

ItemView.prototype.list = function() {
    var table = $(this.items.id);
    this.items.get({
        url: table.attr('data-list-uri'),
        success: function(data) {
            table.html(data);
        },
        errorSibling: table
    });
};

ItemView.prototype.deleteItem = function(e) {
    e.preventDefault();
    var table = $(this.items.id);

    var btn = $(e.target);
    var row = btn.closest('tr');
    var url = btn.attr('href');
    this.items.get({
        url: url,
        success: function(data) {
            showSuccess(table, data.status_msg);
            row.fadeOut('slow', function() { $(this).remove(); });
        },
        errorSibling: table
    });
};
