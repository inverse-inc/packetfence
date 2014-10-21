"use strict";

/*
 * The Nodes class defines the operations available from the controller.
 */
var Nodes = function() {
};

Nodes.prototype.doAjax = function(url_data, options) {
    $.ajax(url_data)
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Nodes.prototype.get = function(options) {
    this.doAjax(options.url, options);
};

Nodes.prototype.post = function(options) {
    this.doAjax(
        {
            url: options.url,
            type: 'POST',
            data: options.data
        },
        options
    );
};

/*
 * The NodeView class defines the DOM operations from the Web interface.
 */
var NodeView = function(options) {
    this.nodes = options.nodes;

    var read = $.proxy(this.readNode, this);
    options.parent.on('click', '#nodes [href*="node"][href$="/read"]', read);

    this.proxyFor($('body'), 'show', '#modalNode', this.showNode);

    this.proxyFor($('body'), 'submit', 'form[name="nodes"]', this.createNode);

    this.proxyFor($('body'), 'submit', 'form[name="simpleNodeSearch"]', this.submitSearch);

    this.proxyFor($('body'), 'submit', 'form[name="advancedNodeSearch"]', this.submitSearch);

    this.proxyFor($('body'), 'submit', '#modalNode form[name="modalNode"]', this.updateNode);

    this.proxyClick($('body'), '#modalNode [href$="/delete"]', this.deleteNode);

    this.proxyFor($('body'), 'show', 'a[data-toggle="tab"][href="#nodeViolations"]', this.readViolations);

    this.proxyClick($('body'), '#modalNode [href*="/close/"]', this.closeViolation);

    this.proxyClick($('body'), '#modalNode [href*="/run/"]', this.runViolation);

    this.proxyClick($('body'), '#modalNode #reevaluateNode', this.reevaluateAccess);

    this.proxyClick($('body'), '#modalNode #addViolation', this.triggerViolation);

    /* Update the advanced search form to the next page or sort the query */
    this.proxyClick($('body'), '.nodes .pagination a', this.searchPagination);

    this.proxyClick($('body'), '#nodes thead a', this.reorderSearch);

    this.proxyClick($('body'), '#toggle_all_items', this.toggleAllItems);

    this.proxyClick($('body'), '[name="items"]', this.toggleActionsButton);

    this.proxyClick($('body'), '#node_bulk_actions .bulk_action', this.submitItems);

    this.proxyFor($('body'), 'section.loaded', '#section', function(e) {
        /* Enable autocompletion of owner on tab of single node creation */
        $('[data-provide="typeahead"]').typeahead({
            source: $.proxy(this.searchUser, this),
            minLength: 2,
            items: 11,
            matcher: function(item) { return true; }
        });
        /* Disable checked columns from import tab since they are required */
        $('form["nodes"] .columns :checked').attr('disabled', 'disabled');
    });
};

NodeView.prototype.proxyFor = function(obj, action, target, method) {
    obj.on(action, target, $.proxy(method, this));
};

NodeView.prototype.proxyClick = function(obj, target, method) {
    this.proxyFor(obj, 'click', target, method);
};

NodeView.prototype.readNode = function(e) {
    e.preventDefault();

    var that = this;
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    this.nodes.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            $('body').append(data);
            var modal = $("#modalNode");
            modal.modal({ show: true });
        },
        errorSibling: section.find('h2').first()
    });
};

NodeView.prototype.showNode = function(e) {
    var that = this;
    var modal = $("#modalNode");
    modal.find('.chzn-select').chosen();
    modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
    modal.find('.timepicker-default').each(function() {
        // Keep the placeholder visible if the input has no value
        var $this = $(this);
        var defaultTime = $this.val().length? 'value' : false;
        $this.timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
        $this.on('hidden', function (e) {
            // Stop the hidden event bubbling up to the modal
            e.stopPropagation();
        });
    });
    modal.find('.datepicker').datepicker({ autoclose: true });
    modal.find('[data-toggle="tooltip"]').tooltip({placement: 'right'}).click(function(e) {
        e.preventDefault;
        return false;
    });
    modal.find('#pid').typeahead({
        source: $.proxy(that.searchUser, that),
        minLength: 2,
        items: 11,
        matcher: function(item) { return true; }
    });
    modal.on('hidden', function (e) {
        if ($(e.target).hasClass('modal')) {
            $(this).remove();
        }
    });
};

NodeView.prototype.searchUser = function(query, process) {
    this.nodes.post({
        url: '/user/advanced_search',
        data: {
            'json': 1,
            'all_or_any': 'any',
            'searches.0.name': 'username',
            'searches.0.op': 'like',
            'searches.0.value': query,
            'searches.1.name': 'email',
            'searches.1.op': 'like',
            'searches.1.value': query
        },
        success: function(data) {
            var results = $.map(data.items, function(i) {
                return i.pid;
            });
            var input = $('#modalNode #pid');
            var control = input.closest('.control-group');
            if (results.length == 0)
                control.addClass('error');
            else
                control.removeClass('error');
            process(results);
        }
    });
};

NodeView.prototype.readViolations = function(e) {
    var btn = $(e.target);
    var name = btn.attr("href");
    var target = $(name.substr(name.indexOf('#')));
    var url = btn.attr("data-href");
    target.load(btn.attr("data-href"), function() {
        target.find('.switch').bootstrapSwitch();
    });
    return true;
};

NodeView.prototype.createNode = function(e) {
    var form = $(e.target),
    btn = form.find('[type="submit"]').first(),
    href = $('#section .nav-tabs .active a').attr('href'),
    pos = href.lastIndexOf('#'),
    disabled_inputs = form.find('.hidden :input, .tab-pane:not(.active) :input'),
    valid;

    // Don't submit inputs from hidden rows and tabs.
    // The functions isFormValid and serialize will ignore disabled inputs.
    disabled_inputs.attr('disabled', 'disabled');

    // Identify the type of creation (single, multiple or import) from the selected tab
    form.find('input[name="type"]').val(href.substr(++pos));
    valid = isFormValid(form);

    if (valid) {
        btn.button('loading');
        resetAlert($('#section'));

        // Since we can be uploading a file, the form target is an iframe from which
        // we read the JSON returned by the server.
        var iform = $("#iframe_form");
        iform.one('load', function(event) {
            // Restore disabled inputs
            disabled_inputs.removeAttr('disabled');

            $("body,html").animate({scrollTop:0}, 'fast');
            btn.button('reset');
            var body = $(this).contents().find('body');
            // We received JSON
            var data = $.parseJSON(body.text());
            if (data.status < 300)
                showPermanentSuccess(form, data.status_msg);
            else
                showPermanentError(form, data.status_msg);
        });
    }
    else {
        // Restore disabled inputs
        disabled_inputs.removeAttr('disabled');
    }

    return valid;
};

NodeView.prototype.updateNode = function(e) {
    e.preventDefault();

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body').first();
    var form = modal.find('form').first();
    var btn = form.find('[type="submit"]').first();
    var valid = isFormValid(form);
    if (valid) {
        resetAlert(modal_body);
        btn.button('loading');

        this.nodes.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                btn.button('reset');
            },
            success: function(data) {
                modal.modal('hide');
            },
            errorSibling: modal_body.children().first()
        });
    }
};

NodeView.prototype.deleteNode = function(e) {
    e.preventDefault();

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var url = btn.attr('href');
    this.nodes.get({
        url: url,
        success: function(data) {
            modal.modal('hide');
        },
        errorSibling: modal_body.children().first()
    });
};

NodeView.prototype.closeViolation = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var row = btn.closest('tr');
    var pane = $('#nodeViolations');
    resetAlert(pane);
    this.nodes.get({
        url: btn.attr("href"),
        success: function(data) {
            showSuccess(pane.children().first(), data.status_msg);
            btn.remove();
            row.addClass('muted');
        },
        errorSibling: pane.children().first()
    });
};

NodeView.prototype.runViolation = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var row = btn.closest('tr');
    var pane = $('#nodeViolations');
    resetAlert(pane);
    this.nodes.get({
        url: btn.attr("href"),
        success: function(data) {
            showSuccess(pane.children().first(), data.status_msg);
            btn.remove();
            row.addClass('muted');
        },
        errorSibling: pane.children().first()
    });
};

NodeView.prototype.triggerViolation = function(e) {
    e.preventDefault();

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var href = btn.attr('href');
    var vid = modal.find('#vid').val();
    var pane = $('#nodeViolations');
    resetAlert(pane);
    this.nodes.get({
        url: [href, vid].join('/'),
        success: function(data) {
            pane.html(data);
            pane.find('.switch').bootstrapSwitch();
        },
        errorSibling: pane.children().first()
    });
};

NodeView.prototype.reevaluateAccess = function(e){
    e.preventDefault();
    
    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var link = $(e.target);
    var url = link.attr('href');
    this.nodes.get({
        url: url,
        success: function(data) {
            showSuccess(modal_body.children().first(), data.status_msg);
        },
        errorSibling: modal_body.children().first()
    });
}

NodeView.prototype.reorderSearch = function(e) {
    e.preventDefault();
    var that = this;
    var link = $(e.currentTarget);
    var pagination = $('.pagination').first();
    var formId = pagination.attr('data-from-from') || '#search';
    var form = $(formId);
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
        that.nodes.post({
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


NodeView.prototype.searchPagination = function(e) {
    var that = this;
    e.preventDefault();
    var link = $(e.currentTarget);
    var pagination = link.closest('.pagination');
    var formId = pagination.attr('data-from-from') || '#search';
    var form = $(formId);
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
        that.nodes.post({
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

NodeView.prototype.submitSearch = function(e) {
    e.preventDefault();
    var that = this;
    var form = $(e.currentTarget);
    var href = form.attr("action");
    var section = $('#section');
    var columns = $('#columns');
    $("body,html").animate({scrollTop:0}, 'fast');
    var status_container = $("#section").find('h2').first();
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5, function() {
        that.nodes.post({
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

NodeView.prototype.toggleActionsButton = function(e) {
    var dropdown = $('#bulk_actions + ul');
    var checked = $('[name="items"]:checked').length > 0;
    if (checked)
        dropdown.find('li.disabled').removeClass('disabled');
    else
        dropdown.find('li[class!="dropdown-submenu"]').addClass('disabled');
};

NodeView.prototype.toggleAllItems = function(e) {
    var target = $(e.currentTarget);
    $('[name="items"]').attr("checked", target.is(':checked'));
    this.toggleActionsButton();
    return true;
};

NodeView.prototype.submitItems = function(e) {
    var target = $(e.currentTarget);
    var status_container = $("#section").find('h2').first();
    var items = $("#items").serialize();
    if (items.length) {
        this.nodes.post({
            url: target.attr("data-target"),
            data: items,
            success: function(data) {
                $("#section").one('section.loaded', function() {
                    showSuccess($("#section").find('h2').first(), data.status_msg);
                });
                $(window).hashchange();
            },
            errorSibling: status_container
        });
    }
};
