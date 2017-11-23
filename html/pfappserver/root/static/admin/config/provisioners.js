/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    var items = new Provisioners();
    var view = new ProvisionerView({ items: items, parent: $('#section') });
});

/*
 * The Provisioners class defines the operations available from the controller.
 */
var Provisioners = function() {
};

Provisioners.prototype = new Items();

Provisioners.prototype.id  = '#provisioners';

Provisioners.prototype.formName  = 'modalProvisioner';

Provisioners.prototype.modalId   = '#modalProvisioner';

Provisioners.prototype.createSelector = ".createProvisioner";

/*
 * The ProvisionerView class defines the DOM operations from the Web interface.
 */


var ProvisionerView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
    var toggleInputs = $.proxy(this.toggleInputs,this);
    // Hide the sectype, eap_type fields when 'Open' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="security_type"]', toggleInputs);
    // Hide the ca_cert_path, cert_type and company fields when 'PEAP' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="eap_type"]', toggleInputs);
    // Hide fileds on opening the provisioner
    options.parent.on('show', '#modalProvisioner', toggleInputs);
};

ProvisionerView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

ProvisionerView.prototype.constructor = ProvisionerView;

ProvisionerView.prototype.toggleInputs = function(e) {
    this.togglePkiProvider(e);
    this.toggleWifiKey(e);
    this.toggleEapType(e);
    this.toggleServerCertificate(e);
};

ProvisionerView.prototype.toggleWifiKey = function(e) {
    var security_type = $('#security_type option:selected').text();
    var eap_type = $('#eap_type option:selected').text();
    var passcode_input = $('#passcode').closest('.control-group');
    if (security_type != "Open" && eap_type == "No EAP") {
        passcode_input.show();
    }
    else {
        passcode_input.hide();
    }
};

ProvisionerView.prototype.toggleEapType = function(e) {
    var security_type = $('#security_type option:selected').text();
    var eap_input = $('#eap_type').closest('.control-group');
    if ( security_type == 'WPA2') {
        eap_input.show();
    }
    else {
        eap_input.hide();
    }
};

ProvisionerView.prototype.togglePkiProvider = function(e) {
    var security_type = $('#security_type option:selected').text();
    var eap_type = $('#eap_type option:selected').text();
    var pki_input = $('#pki_provider').closest('.control-group');
    if (security_type == "WPA2" && eap_type == "EAP-TLS") {
        pki_input.show();
    }
    else {
        pki_input.hide();
    }
};

ProvisionerView.prototype.toggleServerCertificate = function(e) {
    var security_type = $('#security_type option:selected').text();
    var eap_type = $('#eap_type option:selected').text();
    var server_certificate = $('#server_certificate_path').closest('.control-group');
    if (security_type == "WPA2" && eap_type == "PEAP") {
        server_certificate.show();
    }
    else {
        server_certificate.hide();
    }
};



