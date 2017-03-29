/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    var items = new Pfdetects();
    var view = new PfdetectView({ items: items, parent: $('#section') });
});

/*
 * The Pfdetects class defines the operations available from the controller.
 */
var Pfdetects = function() {
};

Pfdetects.prototype = new Items();

Pfdetects.prototype.id  = '#pfdetects';

Pfdetects.prototype.formName  = 'modalPfdetect';

Pfdetects.prototype.modalId   = '#modalPfdetect';

/*
 * The PfdetectView class defines the DOM operations from the Web interface.
 */


var PfdetectView = function(options) {
    ItemView.call(this, options);
    var that = this;
    this.parent = options.parent;
    var items = options.items;
    this.items = items;
    var id = items.id;
    var formName = items.formName;
    options.parent.off('click', id + ' [href$="/clone"]');

    var showTestRegex = $.proxy(this.showTestRegex, this);
    options.parent.on('show', '#test-regex', showTestRegex);

    var toggleResults = $.proxy(this.toggleResults, this);
    options.parent.on('shown', '#test-regex-results .collapse', toggleResults);
    options.parent.on('hidden', '#test-regex-results .collapse', toggleResults);

    var testRegex = $.proxy(this.testRegex, this);
    options.parent.on('click', '#test-regex-btn', testRegex);

    var handleChangeApiMethod = this.handleChangeApiMethod;
    options.parent.on('change', 'form[name="modalPfdetect"] [name$=".api_method"]', handleChangeApiMethod);
};

PfdetectView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

PfdetectView.prototype.constructor = PfdetectView;

PfdetectView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var table = $(this.items.id);
    var section = $('#section');
    var btn = form.find('.btn-primary');
    var valid = isFormValid(form);
    if (valid) {
        var alert_element = form.find('h2').first();
        btn.button('loading');
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                btn.button('reset');
            },
            success: function(data, textStatus, jqXHR) {
                var redirect = jqXHR.getResponseHeader('Location');
                showSuccess(alert_element, data.status_msg);
                if (redirect) {
                    location.hash = redirect;
                }
            },
            errorSibling: alert_element
        });
    }
};

PfdetectView.prototype.toggleResults = function(e) {
    var div = $(e.currentTarget);
    var icon = $('a[data-target="#'+ div.attr("id") + '"] i');
    if (icon.length) {
        icon.toggleClass("icon-minus-sign", 1);
    }
};

PfdetectView.prototype.testRegex = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var form = $(btn.closest('form').first());
    var valid = isFormValid(form);
    if (valid) {
        var action = btn.attr("data-test-action");
        var section = $('#section');
        btn.button('loading');
        this.items.post({
            url: action,
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                btn.button('reset');
            },
            success: function(data) {
                showSuccess(section.find('h2').first(), "Passed");
                $('#test-regex-results').html(data);
            },
            errorSibling: section.find('h2').first()
        });
    }
    return false;
};

PfdetectView.prototype.showTestRegex = function(e) {
    $('textarea[name="loglines"]').removeAttr('disabled');
};

PfdetectView.prototype.handleChangeApiMethod = function(e) {
    var search_input = $(e.currentTarget);
    var api_parameters_input = search_input.next();
    var search_type = search_input.val();
    var api_parameters_id = '#' + search_type + "_api_parameters";
    var api_parameters_template = $(api_parameters_id);
    if (api_parameters_template.length === 0) {
        api_parameters_template = $('#default_api_parameters');
    }
    if (api_parameters_template.length) {
        changeInputFromTemplate(api_parameters_input, api_parameters_template);
    }
};


function submitFormGoToLocation(form) {
    $.ajax({
        'async' : false,
        'url'   : form.attr('action'),
        'type'  : form.attr('method') || "POST",
        'data'  : form.serialize()
        })
        .done(function(data, textStatus, jqXHR) {
            location.hash = jqXHR.getResponseHeader('Location');
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
        });
}

