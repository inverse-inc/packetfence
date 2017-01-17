$(function() { // DOM ready
    var items = new Sources();
    var view = new SourceView({ items: items, parent: $('#section') });
});

/*
 * The Sources class defines the operations available from the controller.
 */
var Sources = function() {
};

Sources.prototype = new Items();

Sources.prototype.id  = '#sources';

Sources.prototype.formName  = 'modalSource';

Sources.prototype.modalId   = '#modalSource';

/*
 * The SourceView class defines the DOM operations from the Web interface.
 */


var SourceView = function(options) {
    ItemView.call(this, options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
};

SourceView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

SourceView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var btn = form.find('.btn-primary');
    var valid = isFormValid(form);
    if (valid) {
        var table = $(this.items.id);
        btn.button('loading');
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                btn.button('reset');
            },
            success: function(data, textStatus, jqXHR) {
                var redirect = jqXHR.getResponseHeader('Location');
                if (redirect) {
                    location.hash = jqXHR.getResponseHeader('Location');
                }
                else {
                    showSuccess(table, data.status_msg);
                    that.list();
                }
            },
            errorSibling: form.prev()
        });
    }
};

SourceView.prototype.constructor = SourceView;
