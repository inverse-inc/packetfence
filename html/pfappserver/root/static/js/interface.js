"use strict";

/*
 * The Interfaces class defines the operations available from the controller.
 */
var Interfaces = function() {
};

Interfaces.prototype.get = function(options) {
    $.ajax({
        url: options.url
    })
        .always(options.always)
        .done(options.success)
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(options.errorSibling, status_msg);
        });
};

Interfaces.prototype.post = function(options) {
    $.ajax({
        url: options.url,
        type: 'POST',
        data: options.data
    })
        .always(options.always)
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
    options.parent.on('click', '#interfaces [href$="/read"], #interfaces [href$="/create"], #interfaces [href$="/view"]', read);

    var update = $.proxy(this.updateInterface, this);
    options.parent.on('submit', 'form[name="modalEditInterface"], form[name="modalCreateVlan"]', update);

    var delete_i = $.proxy(this.deleteInterface, this);
    options.parent.on('click', '#interfaces [href$="/delete"]', delete_i);

    var toggle = $.proxy(this.toggleInterface, this);
    options.parent.on('switch-change', '#interfaces .switch', toggle);

    var typeChanged = $.proxy(this.typeChanged, this);
    options.parent.on('change', '[name="type"]', typeChanged);

    var fakeMacChanged = $.proxy(this.fakeMacChanged, this);
    options.parent.on('change', '[name="fake_mac_enabled"]', fakeMacChanged);

    var delete_n = $.proxy(this.deleteNetwork, this);
    options.parent.on('click', 'form[name="modalEditInterface"] [href$="/delete"]', delete_n);

    var loadTab = $.proxy(this.loadTab, this);
    options.parent.on('click', 'a[data-toggle="tab"][href="configuration/roles"]', this.loadtab);
    //options.parent.on('click', 'a[data-toggle="tab"][href="#additionalTabView"]', this.loadtab);

};

InterfaceView.prototype.loadTab = function(e) {
    var btn = $(e.target);
    console.log('tt');
    var name = btn.attr("href");
    var target = $(name);
    var url = btn.attr("data-href");
    target.load(url, function() {
        target.find('.switch').bootstrapSwitch();
    });
    return true;
}

InterfaceView.prototype.readInterface = function(e) {
    e.preventDefault();

    var that = this;
    var modal = $('#modalEditInterface');
    var section = $('#section');
    var loader = section.prev('.loader');
    loader.show();
    section.fadeTo('fast', 0.5);
    modal.empty();
    this.interfaces.get({
        url: $(e.target).attr('href'),
        always: function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        },
        success: function(data) {
            modal.append(data);
            modal.find('.switch').bootstrapSwitch();
            modal.find('.chzn-select').chosen();
            modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
            modal.find('[name="dns"]').closest('.control-group').hide();
            modal.find('[name="dhcpd_enabled"]').closest('.control-group').hide();
            modal.find('[name="high_availability"]').closest('.control-group').hide();
            modal.find('[name="vip"]').closest('.control-group').hide();
            modal.find('[name="fake_mac_enabled"]').closest('.control-group').hide();
            modal.find('[name="nat_enabled"]').closest('.control-group').hide();
            modal.modal({ shown: true });
            modal.one('shown', function() {
                modal.find(':input:visible').first().focus();
                that.typeChanged();
                that.fakeMacChanged();
            });
        },
        errorSibling: section.find('h2').first()
    });
};

InterfaceView.prototype.typeChanged = function(e) {
    var modal = $('#modalEditInterface');
    if (modal.find('[name="ipaddress"]').length) {
        // We are editing an interface
        var type = e? $(e.target) : modal.find('[name="type"]');
        if (type.length) {
            var dns = modal.find('[name="dns"]').closest('.control-group');
            var dhcpd = modal.find('[name="dhcpd_enabled"]').closest('.control-group');
            var high_availability = modal.find('[name="high_availability"]').closest('.control-group');
            var vip = modal.find('[name="vip"]').closest('.control-group');
            var nat = modal.find('[name="nat_enabled"]').closest('.control-group');

            switch ( type.val() ) {
                case 'inlinel2': 
                    dns.show('fast');
                    dns.find(':input').removeAttr('disabled');
                    dhcpd.show('fast');
                    high_availability.hide('fast');
                    high_availability.find(':input').attr('disabled','disabled');
                    vip.show('fast');
                    vip.find(':input').removeAttr('disabled');
                    nat.show('fast');
                    nat.find(':input').removeAttr('disabled');
                    $(".info_inline").show('fast');
                    if (modal.find('[name="nat_enabled"]').is(":checked")) {
                        $(".info_routed").hide('fast');
                    } else {
                        $(".info_routed").show('fast');
                    }
                    modal.find('[name="nat_enabled"]').change(function(){
                        if (this.checked) {
                            $(".info_routed").hide('fast');
                        } else {
                            $(".info_routed").show('fast');
                        }
                    });
                    break;
                case 'management':
                    dhcpd.hide('fast');
                    high_availability.show('fast');
                    high_availability.find(':input').removeAttr('disabled');
                    dns.hide('fast');
                    dns.find(':input').attr('disabled','disabled');
                    vip.show('fast');
                    vip.find(':input').removeAttr('disabled');
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
                    $(".info_inline").hide('fast');
                    $(".info_routed").hide('fast');
                    break;
                case '':
                case 'none':
                    dhcpd.hide('fast');
                    high_availability.show('fast');
                    high_availability.find(':input').removeAttr('disabled');
                    dns.hide('fast');
                    dns.find(':input').attr('disabled','disabled');
                    vip.hide('fast');
                    vip.find(':input').attr('disabled','disabled');
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
                    $(".info_inline").hide('fast');
                    $(".info_routed").hide('fast');
                    break;
                case 'other':
                    dhcpd.hide('fast');
                    high_availability.hide('fast');
                    high_availability.find(':input').attr('disabled','disabled');
                    dns.hide('fast');
                    dns.find(':input').attr('disabled','disabled');
                    vip.hide('fast');
                    vip.find(':input').attr('disabled','disabled');
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
                    $(".info_inline").hide('fast');
                    $(".info_routed").hide('fast');
                    break;
                case 'dns-enforcement':
                case 'vlan-registration':
                case 'vlan-isolation':
                    vip.show('fast');
                    vip.find(':input').removeAttr('disabled');
                    high_availability.hide('fast');
                    high_availability.find(':input').attr('disabled','disabled');
                    dhcpd.show('fast');
                    dns.hide('fast');
                    dns.find(':input').attr('disabled','disabled');
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
                    $(".info_inline").hide('fast');
                    $(".info_routed").hide('fast');
                    break;
                default:
                    dhcpd.hide('fast');
                    high_availability.hide('fast');
                    high_availability.find(':input').attr('disabled','disabled');
                    dns.hide('fast');
                    dns.find(':input').attr('disabled','disabled');
                    vip.show('fast');
                    vip.find(':input').removeAttr('disabled');
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
                    $(".info_inline").hide('fast');
                    $(".info_routed").hide('fast');
            }
        }
    }
    else if (modal.find('[name="network"]').length) {
        // We are editing a network
        var type = e? $(e.target) : modal.find('[name="type"]');
        modal.find('[name="dns"]').closest('.control-group').show();
        if (type.length) {
            var fake_mac = modal.find('[name="fake_mac_enabled"]').closest('.control-group');
            var nat = modal.find('[name="nat_enabled"]').closest('.control-group');

            switch ( type.val() ) {
                case 'inlinel3':
                    fake_mac.show('fast');
                    fake_mac.find(':input').removeAttr('disabled');
                    nat.show('fast');
                    nat.find(':input').removeAttr('disabled');
                    break;
                default:
                    fake_mac.find(':input').attr('checked', false);
                    fake_mac.hide('fast');
                    fake_mac.find(':input').attr('disabled','disabled');
                    this.fakeMacChanged();
                    nat.find(':input').attr('checked', false);
                    nat.hide('fast');
                    nat.find(':input').attr('disabled','disabled');
            }
        }
    }
};

InterfaceView.prototype.fakeMacChanged = function(e) {
    var modal = $('#modalEditInterface');
    var fake_mac = e? $(e.target) : modal.find('[name="fake_mac_enabled"]');
    if (fake_mac.length) {
        var dhcp = $('#dhcp_section');
        var dhcpd = modal.find('[name="dhcpd_enabled"]').closest('.control-group');
        if (fake_mac.is(':checked')) {
            dhcpd.find(':input').attr('disabled','disabled');
            dhcp.find(':input').attr('disabled','disabled');
        }
        else {
            dhcp.find(':input').removeAttr('disabled');
            dhcpd.find(':input').attr('enabled','enabled');
        }
    }
};

InterfaceView.prototype.updateInterface = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var btn = form.find('.btn-primary');
    var modal = $('#modalEditInterface');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        btn.button('loading');
        this.interfaces.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                btn.button('reset');
            },
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
    this.interfaces.get({
        url: '/interface/list',
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
    var row_network = row.next('.network');
    var url = btn.attr('href');
    this.interfaces.get({
        url: url,
        success: function(data) {
            showSuccess($('#interfaces table'), data.status_msg);
            row_network.fadeOut('slow', function() { $(this).remove(); });
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
            // Update all interfaces status
            $.each(data.interfaces, function(i, status) {
                if (i !== name)
                    $('input:checkbox[name="'+i+'"]').closest('.switch').bootstrapSwitch('setState', status === "1");
            });
            that.disableToggle = false;
        },
        error: function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError($('#interfaces table'), status_msg);
            // Restore switch state
            btn.bootstrapSwitch('setState', !status, true);
            that.disableToggle = false;
        }
    });
};

InterfaceView.prototype.deleteNetwork = function(e) {
    e.preventDefault();

    var that = this;
    var btn = $(e.target);
    var url = btn.attr('href');
    var modal = $('#modalEditInterface');
    var modal_body = modal.find('.modal-body').first();
    resetAlert(modal_body);
    this.interfaces.get({
        url: url,
        success: function(data) {
            showSuccess($('#interfaces table'), data.status_msg);
            modal.modal('toggle');
            that.list();
        },
        errorSibling: modal_body.children().first()
    });
};
