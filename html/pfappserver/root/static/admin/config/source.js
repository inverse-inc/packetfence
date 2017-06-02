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
    var id = options.items.id;
    options.parent.off('click', id + ' [href$="/clone"]');
    options.parent.off('click', id + ' [href$="/delete"]');
    var changeRuleClass = $.proxy(this.changeRuleClass, this);
    options.parent.on('change', 'form[name="modalSource"] select[name$="class"]', changeRuleClass);
};

SourceView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

SourceView.prototype.changeRuleClass = function(e) {
    var select = $(e.target);
    var type = select.attr("value");
    var name = select.attr("name");
    var rule_id = name.replace(".class","");
    var rule = select.closest(escapeJqueryId("#" + "accordion." + rule_id));
    var actions_id =  escapeJqueryId('#' + rule_id + ".actions");
    var actions = $(actions_id);
    var show_options_selector = 'option[data-rule-class="' + type + '"]';
    var shown_options = actions.find(show_options_selector);
    shown_options.removeClass('hidden');
    shown_options.removeAttr('disabled');
    var hidden_options = actions.find('option[data-rule-class!="' + type + '"]');
    hidden_options.addClass('hidden');
    hidden_options.attr('disabled', 'disabled');
};

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
            errorSibling: form
        });
    }
};

SourceView.prototype.constructor = SourceView;
