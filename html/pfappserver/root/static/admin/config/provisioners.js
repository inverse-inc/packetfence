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

/*
 * The ProvisionerView class defines the DOM operations from the Web interface.
 */


var ProvisionerView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;

    // Hide the sectype, eap_type fields when 'Open' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="security_type"]', this.toggleSecurityType);
    // Hide the ca_cert_path, cert_type, reversedns and company fields when 'PEAP' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="eap_type"]', this.toggleEapType);
    // Hide fileds on opening the provisioner
    options.parent.on('show', '#modalProvisioner', function(e) {
      that.toggleEapType(e);
      that.toggleSecurityType(e);
    }); 
};

ProvisionerView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

ProvisionerView.prototype.constructor = ProvisionerView;

ProvisionerView.prototype.toggleSecurityType = function(e) {
    var select = $('form[name="modalProvisioner"] select[name="security_type"]').first();
    var passcode_input = select.closest('form').find('input[name="passcode"]');
    var passcode = passcode_input.closest('.control-group');
    var eap = select.closest('form').find('select[name="eap_type"]').closest('.control-group');
    var eap_type = $('form[name="modalProvisioner"] select[name="eap_type"]').first();
    var cert = eap_type.closest('form').find('select[name="cert_type"]').closest('.control-group');
    var certpath = eap_type.closest('form').find('input[name="ca_cert_path"]').closest('.control-group');

    if ($('#security_type option:selected').text() == "Open"){
        passcode_input.val("");
        passcode.hide();
        eap.hide();
        eap_type.val("");
        cert.hide();
        certpath.hide();
    }
    else if ($('#security_type option:selected').text() == "WEP"){
        passcode_input.val("");
        passcode.show();
        eap.hide();
        eap_type.val("");
        cert.hide();
        certpath.hide();
    }
    else{
        passcode.show();
        eap.show();
        cert.show();
        certpath.show();
    }
};

ProvisionerView.prototype.toggleEapType = function(e) {
    var select = $('form[name="modalProvisioner"] select[name="eap_type"]').first();
    var cert = select.closest('form').find('select[name="cert_type"]').closest('.control-group');
    var certpath_input = select.closest('form').find('input[name="ca_cert_path"]');
    var certpath = certpath_input.closest('.control-group');
    var passcode = select.closest('form').find('input[name="passcode"]').closest('.control-group');

    if ($('#eap_type option:selected').text() == "PEAP"){
        certpath_input.val("");
        certpath.hide();
        cert.hide();
        passcode.hide();
    }
    else if ($('#eap_type option:selected').text() == "No EAP"){
        certpath_input.val("");
        certpath.hide();
        cert.hide();
        passcode.show();
    }
    else if ($('#eap_type option:selected').text() == "EAP-TLS"){
        certpath.show();
        cert.show();
        passcode.hide();
    }
    else{
        cert.show();
        certpath.show();
        passcode.hide();
    }
};
