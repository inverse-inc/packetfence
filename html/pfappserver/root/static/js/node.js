/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

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
            if (options.errorSibling) {
                var status_msg = getStatusMsg(jqXHR);
                showError(options.errorSibling, status_msg);
            }
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
            data: options.data,
            timeout: 300000,
        },
        options
    );
};

/*
 * The NodeView class defines the DOM operations from the Web interface.
 */
var NodeView = function(options) {
    var that = this;
    this.nodes = options.nodes;

    var read = $.proxy(this.readNode, this);
    var body = $('body');
    options.parent.on('click', '[href*="node"][href*="/read"]', read);

    this.proxyClick(body, '.node [href*="node"][href*="/read"]', this.readNode);

    this.proxyFor(body, 'show', '#modalNode', this.showNode);

    this.proxyFor(body, 'submit', 'form[name="nodes"]', this.createNode);

    this.proxyFor(body, 'submit', 'form[name="simpleNodeSearch"]', this.submitSearch);

    this.proxyFor(body, 'change', 'form[name="simpleNodeSearch"] [name$=".name"]', this.changeSearchField);

    this.proxyFor(body, 'change', 'form[name="simpleNodeSearch"] [name$=".op"]', this.changeOpField);

    this.proxyFor(body, 'click', '#simpleNodeSearchResetBtn', this.resetSimpleSearch);

    this.proxyFor(body, 'submit', 'form[name="advancedNodeSearch"]', this.submitSearch);

    this.proxyFor(body, 'click', '#advancedNodeSearchResetBtn', this.resetAdvancedSearch);

    this.proxyFor(body, 'change', 'form[name="advancedNodeSearch"] [name$=".name"]', this.changeSearchField);

    this.proxyFor(body, 'change', 'form[name="advancedNodeSearch"] [name$=".op"]', this.changeOpField);

    this.proxyFor(body, 'submit', '#modalNode form[name="modalNode"]', this.updateNode);

    this.proxyClick(body, '#modalNode [href*="node"][href8="/delete"]', this.deleteNode);

    this.proxyFor(body, 'show', 'a[data-toggle="tab"][href="#nodeSecurityEvents"]', this.loadTab);

    this.proxyFor(body, 'show', 'a[data-toggle="tab"][href="#nodeAdditionalTabView"]', this.loadTab);

    this.proxyFor(body, 'click', '[data-href*="/node"][data-href*="/tab_process"]', this.tabProcess);

    this.proxyClick(body, '#modalNode [href*="/close/"]', this.closeSecurityEvent);

    this.proxyClick(body, '#modalNode [href*="/run/"]', this.runSecurityEvent);

    this.proxyClick(body, '#modalNode #reevaluateNode', this.reevaluateAccess);
    
    this.proxyClick(body, '#modalNode #refreshFingerbankDeviceNode', this.refreshFingerbankDevice);
    
    this.proxyClick(body, '#modalNode #restartSwitchport', this.restartSwitchport);

    this.proxyClick(body, '#modalNode #addSecurityEvent', this.triggerSecurityEvent);
    
    this.proxyClick(body, '#modalNode #runRapid7Scan', this.runRapid7Scan);

    /* Update the advanced search form to the next page or sort the query */
    this.proxyClick(body, '.nodes .pagination a', this.searchPagination);

    this.proxyClick(body, '#nodes thead a', this.reorderSearch);

    this.proxyClick(body, '#toggle_all_items', this.toggleAllItems);

    this.proxyClick(body, '[name="items"]', this.toggleActionsButton);

    this.proxyClick(body, '#node_bulk_actions .bulk_action', this.submitItems);

    this.proxyClick(body, '[id$="Empty"] [href="#add"]', function(e) {
        var emptyDiv = $(e.currentTarget).closest('[id$="Empty"]');
        var match = /(.+)Empty/.exec(emptyDiv.attr('id'));
        var id = match[1];
        var emptyId = match[0];
        $('#'+id).trigger('addrow');
        $('#'+emptyId).addClass('hidden');
        return false;
    });

    this.proxyFor(body, 'section.loaded', '#section', function(e) {
        /* Disable checked columns from import tab since they are required */
        $('form[name="nodes"] .columns :checked').attr('disabled', 'disabled');
    });
    this.proxyFor(body, 'saved_search.loaded', 'form[name="advancedNodeSearch"] [name$=".name"]', this.changeSearchFieldKeep);

    this.proxyFor(body, 'saved_search.loaded', 'form[name="advancedNodeSearch"] [name$=".op"]', this.changeOpFieldKeep);

    this.proxyFor(body, 'saved_search.loaded', 'form[name="simpleNodeSearch"] [name$=".name"]', this.changeSearchFieldKeep);

    this.proxyFor(body, 'saved_search.loaded', 'form[name="simpleNodeSearch"] [name$=".op"]', this.changeOpFieldKeep);
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
    section.loader();
    section.fadeTo('fast', 0.5);
    this.nodes.get({
        url: $(e.target).attr('href'),
        always: function() {
            section.stop();
            section.fadeTo('fast', 1.0, function() {
                section.loader('hide');
            });
        },
        success: function(data) {
            $('body').append(data);
            var modal = $("#modalNode");
            /* Ability to track submitted button (multihost feature) */
            modal.find("form button[type=submit]").click(function() {
                $(this, $(this).parents("form")).removeAttr("clicked");
                $(this).attr("clicked", "true");
            });
            modal.on('hidden', function () {
                modal.remove();
                $("#modalNode").remove();
            });
            modal.modal({ show: true });
        },
        errorSibling: section.find('h2').first()
    });
};

NodeView.prototype.showNode = function(e) {
    var that = this;
    var modal = $("#modalNode");
    modal.find('.chzn-select').chosen({width: ''});
    modal.find('.chzn-deselect').chosen({allow_single_deselect: true, width: ''});
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
    modal.find('.input-date').datepicker({ autoclose: true });

    modal.find('[data-toggle="tooltip"]').tooltip({placement: 'right'}).click(function(e) {
        e.preventDefault();
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

NodeView.prototype.loadTab = function(e) {
    var btn = $(e.target);
    var name = btn.attr("href");
    var target = $(name);
    var url = btn.attr("data-href");
    target.load(url, function() {
        target.find('.switch').bootstrapSwitch();
    });
    return true;
}

NodeView.prototype.tabProcess = function(e) {
    var a = $(e.target);
    var name = a.attr("href");
    var target = $(name);
    var url = a.attr("data-href");
    this.nodes.get({
        url: url,
        always: function(data) {
            if (typeof data === 'object') {
                target.html(data.responseText);
            } else {
                target.html(data);
            }
        }
    });
    return false;
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
            if (data.status < 300){
                showPermanentSuccess(form, data.status_msg);
                // We also empty the MAC field for when creating single nodes
                $('#mac').val('');
            }
            else {
                showPermanentError(form, data.status_msg);
            }
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

    var that = this;
    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body').first();
    var form = modal.find('form').first();
    var btn = form.find('[type="submit"]').first();
    var valid = isFormValid(form);

    var submitted_button = form.find("button[type=submit][clicked=true]");
    if (submitted_button.attr("data-multihost")) {
        form.find('[name="multihost"]').val("yes");
    } else {
        form.find('[name="multihost"]').val("no");
    }

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
                modal.on('hidden', function() {
                    that.refreshPage();
                });
            },
            errorSibling: modal_body.children().first()
        });
    }
};

NodeView.prototype.deleteNode = function(e) {
    e.preventDefault();
    var that = this;

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var url = btn.attr('href');
    this.nodes.get({
        url: url,
        success: function(data) {
            modal.modal('hide');
            modal.on('hidden', function() {
                that.refreshPage();
            });
        },
        errorSibling: modal_body.children().first()
    });
};

NodeView.prototype.closeSecurityEvent = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var row = btn.closest('tr');
    var pane = $('#nodeSecurityEvents');
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

NodeView.prototype.runSecurityEvent = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var row = btn.closest('tr');
    var pane = $('#nodeSecurityEvents');
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

NodeView.prototype.triggerSecurityEvent = function(e) {
    e.preventDefault();

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var option = modal.find('#security_event_id').find(':selected');
    var href = option.attr("trigger_url");
    var pane = $('#nodeSecurityEvents');
    resetAlert(pane);
    this.nodes.get({
        url: href,
        success: function(data) {
            pane.html(data);
            pane.find('.switch').bootstrapSwitch();
        },
        errorSibling: pane.children().first()
    });
};

NodeView.prototype.runRapid7Scan = function(e) {
    e.preventDefault();

    var modal = $('#modalNode');
    var modal_body = modal.find('.modal-body');
    var btn = $(e.target);
    var option = modal.find('#rapid7ScanTemplateSelection').find(':selected');
    var href = option.attr("trigger_url");
    var pane = $('#runRapid7Scan').closest('div');
    resetAlert(pane);
    this.nodes.get({
        url: href,
        success: function(data) {
            showSuccess(pane, data.status_msg);
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

NodeView.prototype.refreshFingerbankDevice = function(e){
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

NodeView.prototype.restartSwitchport = function(e){
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
    var formId = pagination.attr('data-from-form') || '#search';
    var form = $(formId);
    if (form.length == 0) {
        form = $('#search');
    }
    var columns = $('#columns');
    var href = link.attr("href");
    var section = $('#section');
    var status_container = $("#section").find('h2').first();
    section.loader();
    section.fadeTo('fast', 0.5);
    section.fadeTo('fast', 0.5, function() {
        that.nodes.post({
            url: href,
            data: form.serialize() + "&" + columns.serialize(),
            always: function() {
                section.fadeTo('fast', 1.0, function() {
                    section.loader('hide');
                });
            },
            success: function(data) {
                section.html(data);
                section.trigger('section.loaded');
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
    var formId = pagination.attr('data-from-form') || '#search';
    var form = $(formId);
    if (form.length == 0) {
        form = $('#search');
    }
    var columns = $('#columns');
    var href = link.attr("href");
    var section = $('#section');
    var status_container = $("#section").find('h2').first();
    section.loader();
    section.fadeTo('fast', 0.5, function() {
        that.nodes.post({
            url: href,
            data: form.serialize() + "&" + columns.serialize(),
            always: function() {
                section.fadeTo('fast', 1.0, function() {
                    section.loader('hide');
                });
            },
            success: function(data) {
                section.html(data);
                section.trigger('section.loaded');
            },
            errorSibling: status_container
        });
    });
    return false;
};

NodeView.prototype.refreshPage = function() {
    var that = this;
    var pagination = $('.pagination').first();
    if (pagination.attr('data-no-refresh') == "yes") {
        return;
    }
    var formId = pagination.attr('data-from-form') || '#search';
    var form = $(formId);
    var link = pagination.find('li.disabled a').first();
    if (form.length == 0) {
        form = $('#search');
    }
    var columns = $('#columns');
    var href = link.attr("href");
    var section_id = pagination.attr('data-section') || "#section";
    var refresh_section = $(section_id);
    var section = $('#section');
    var status_container = section.find('h2').first();
    var form_data = form.serialize();
    if (columns.length == 0) {
        form_data += "&" + columns.serialize();
    }
    section.loader();
    section.fadeTo('fast', 0.5);
    section.fadeTo('fast', 0.5, function() {
        that.nodes.post({
            url: href,
            data: form_data,
            always: function() {
                section.fadeTo('fast', 1.0, function() {
                    section.loader('hide');
                });
            },
            success: function(data) {
                refresh_section.html(data);
                section.trigger('section.loaded');
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
    section.loader();
    section.fadeTo('fast', 0.5, function() {
        that.nodes.post({
            url: href,
            data: form.serialize() + "&" + columns.serialize(),
            always: function() {
                section.fadeTo('fast', 1.0, function() {
                    section.loader('hide');
                });
            },
            success: function(data) {
                section.html(data);
                section.trigger('section.loaded');
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
    var that = this;
    var target = $(e.currentTarget);
    var section = $('#section');
    var status_container = section.find('h2').first();
    var items = $("#items").serialize();
    if (items.length) {
        section.loader();
        section.fadeTo('fast', 0.5, function() {
            that.nodes.post({
                url: target.attr("data-target"),
                data: items,
                always: function() {
                    section.fadeTo('fast', 1.0, function() {
                        section.loader('hide');
                    });
                },
                success: function(data) {
                    $("#section").one('section.loaded', function() {
                        showSuccess($("#section").find('h2').first(), data.status_msg);
                    });
                    that.refreshPage();
                },
                errorSibling: status_container
            });
        });
    }
};

NodeView.prototype.changeSearchFieldKeep = function(e) {
    this.handleChangeSearchField(e, true);
};

NodeView.prototype.changeSearchField = function(e) {
    this.handleChangeSearchField(e, false);
};

NodeView.prototype.handleChangeSearchField = function(e, keep) {
    var search_input = $(e.currentTarget);
    var op_input = search_input.next();
    var search_type = search_input.val();
    var value_input = op_input.next();
    var op_input_template_id = '#' + search_type + "_op";
    var op_input_template = $(op_input_template_id);
    if (op_input_template.length == 0 ) {
        op_input_template = $('#default_op');
    }
    if (op_input_template.length) {
        changeInputFromTemplate(op_input, op_input_template, keep);
    }
    var value_template_id = '#' + search_type + "_value";
    var value_template = $(value_template_id);
    if (value_template.length == 0 ) {
        value_template = $('#default_value');
    }
    if (value_template.length) {
        changeInputFromTemplate(value_input, value_template, keep);
    }
    this.setupTypeAhead(search_input);
};

NodeView.prototype.changeOpFieldKeep = function(e) {
    this.handleChangeOpField(e, true);
};

NodeView.prototype.changeOpField = function(e) {
    this.handleChangeOpField(e, false);
};

NodeView.prototype.handleChangeOpField = function(e, keep) {
    var op_input = $(e.currentTarget);
    var search_input = op_input.prev();
    var value_input = op_input.next();
    var search_type = search_input.val();
    var op_type = op_input.val();
    var value_template_id = '#' +  search_type + "_value_" + op_type + "_op" ;
    var value_template = $(value_template_id);
    var value_input_id = value_input.attr("id");
    if (value_template.length) {
        changeInputFromTemplate(value_input, value_template, keep);
    }
    this.setupTypeAhead(search_input);
};

NodeView.prototype.setupTypeAhead = function(search_input) {
    var search_type = search_input.val();
    var op_input = search_input.next();
    var value_input = op_input.next();
    var op_input_value = op_input.val();
    if(op_input_value != "equal" && op_input_value != "not_equal") {
        return;
    }
    if(search_type == "switch_id") {
        value_input.typeahead({
            source: $.proxy(this.searchSwitch, this),
            minLength: 2,
            items: 11,
            matcher: function(item) { return true; }
        });
    }
    if(search_type == "person_name") {
        value_input.typeahead({
            source: $.proxy(this.searchUser, this),
            minLength: 2,
            items: 11,
            matcher: function(item) { return true; }
        });
    }
};

NodeView.prototype.searchSwitch = function(query, process) {
    this.nodes.post({
        url: '/config/switch/search',
        data: {
            'json': 1,
            'all_or_any': 'any',
            'searches.0.name': 'id',
            'searches.0.op': 'like',
            'searches.0.value': query,
        },
        success: function(data) {
            var results = $.map(data.items, function(i) {
                return i.id;
            });
            process(results);
        }
    });
}

NodeView.prototype.resetAdvancedSearch = function(e) {
    var form = $('form[name="advancedNodeSearch"]');
    form.find('#advancedSearchConditions').find('tbody').children(':not(.hidden)').find('[href="#delete"]').click();
    form.find('#advancedSearchConditionsEmpty [href="#add"]').click();
    form[0].reset();
    form.submit();
};

NodeView.prototype.resetSimpleSearch = function(e) {
    var form = $('#simpleNodeSearch');
    form[0].reset();
    form.submit();
};
