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
    var items = options.items;
    var id = items.id;
    var formName = items.formName;
    var formSelector = 'form[name="'+ formName + '"]';
    options.parent.off('click', id + ' [href$="/clone"]');
    options.parent.off('click', id + ' [href$="/delete"]');
    options.parent.on('click' , '#testSourceBtn', $.proxy(this.testSource, this));
    options.parent.on('change', formSelector + ' select[name*="\\.conditions\\."][name$=".attribute"]', $.proxy(this.changeCondition, this));
    options.parent.on('change', formSelector + ' select[name*="\\.actions\\."][name$=".type"]', $.proxy(this.changeAction, this));
    options.parent.on('section.loaded', $.proxy(this.loadSource, this));
    options.parent.on('dynamic-list.add', 'div[id^="accordion\\.group\\.administration_rules\\."]', $.proxy(this.addRule, this));
    options.parent.on('dynamic-list.add', 'div[id^="accordion\\.group\\.authentication_rules\\."]', $.proxy(this.addRule, this));

    options.parent.on('dynamic-list.add', 'div[id*="\\.actions\\."]', $.proxy(this.addAction, this));
    options.parent.on('dynamic-list.add', 'div[id*="\\.conditions\\."]', $.proxy(this.addCondition, this));
    options.parent.on('dynamic-list.ordered', id + ' #internal-sources tbody', $.proxy(this.sortItems, this));
};

SourceView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

SourceView.prototype.addCondition = function(e) {
    e.stopPropagation();
    var condition = $(e.target);
    updateSoureRuleCondition(condition.find('select[name*="\\.conditions\\."][name$=".attribute"]'), true);
    return false;
};

SourceView.prototype.addAction = function(e) {
    e.stopPropagation();
    var action = $(e.target);
    updateAction(action.find('select[name*="\\.actions\\."][name$=".type"]'), true);
    return false;
};

SourceView.prototype.addRule = function(e) {
    var rule = $(e.target);
    rule.find('select[name*="\\.actions\\."][name$=".type"]:not(.disabled)').each(function() {
        updateAction($(this), true);
    });
};

SourceView.prototype.loadSource = function(e) {
    var formName = this.items.formName;
    $('#action_templates').find('option').removeAttr('id');
    $('form[name="'+ formName + '"] select[name*="\\.conditions\\."][name$=".attribute"]:not(.disabled)').each(function() {
        updateSoureRuleCondition($(this), true);
    });
    $('form[name="'+ formName + '"] select[name*="\\.actions\\."][name$=".type"]:not(.disabled)').each(function() {
        updateAction($(this), true);
    });
};

SourceView.prototype.changeAction = function(e) {
    updateAction($(e.target), false);
};

SourceView.prototype.changeCondition = function(e) {
    updateSoureRuleCondition($(e.target), false);
};

SourceView.prototype.testSource = function(e) {
    e.preventDefault();
    resetAlert($('#section'));
    var btn = $(e.target);
    var form = btn.closest('form');
    var valid = isFormValid(form);
    var alertSibling = btn.closest('.input-append');
    if (valid) {
        this.items.post({
            url: btn.attr('href'),
            data: form.serialize(),
            always: function() {
                btn.button('reset');
            },
            success: function(data, textStatus, jqXHR) {
                showSuccess(alertSibling, data.status_msg);
            },
            errorSibling: btn.closest(alertSibling)
        });
    } else {
        showError(alertSibling, "Required field missing");
    }
};

SourceView.prototype.sortItems = function(e) {
    var form = $(e.target).closest('form');
    this.items.post({
        url: form.attr('action'),
        data: form.serialize(),
        success: function(data, textStatus, jqXHR) {
            showSuccess(form, data.status_msg);
        },
        errorSibling: form
    });
};

SourceView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var btn = form.find('.btn-primary');
    var valid = isFormValid(form);
    if (valid) {
        btn.button('loading');
        resetAlert($('#section'));
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                $("body,html").animate({scrollTop:0}, 'fast');
                btn.button('reset');
            },
            success: function(data, textStatus, jqXHR) {
                var redirect = jqXHR.getResponseHeader('Location');
                if (redirect) {
                    location.hash = jqXHR.getResponseHeader('Location');
                }
                else {
                    showSuccess(form, data.status_msg);
                }
            },
            errorSibling: form
        });
    }
};

SourceView.prototype.constructor = SourceView;
