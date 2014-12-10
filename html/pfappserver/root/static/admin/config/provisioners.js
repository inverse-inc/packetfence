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

    // Hide the passcode field when 'Open' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="security_type"]', this.togglepasscode);
    // Hide the ca_cert_path, cert_type, reversedns and company fields when 'PEAP' is selected
    options.parent.on('change', 'form[name="modalProvisioner"] select[name="eap_type"]', this.togglecert);
    // Hide fileds on opening the provisioner
    options.parent.on('show', '#modalProvisioner', function(e) {
      that.togglecert(e);
      that.togglepasscode(e);
    }); 
};

ProvisionerView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

ProvisionerView.prototype.constructor = ProvisionerView;

ProvisionerView.prototype.togglepasscode = function(e) {
    var select = $('form[name="modalProvisioner"] select[name="security_type"]').first();
    var passcode = select.closest('form').find('input[name="passcode"]').closest('.control-group');

    if ($('#security_type option:selected').text() == "Open")
        passcode.hide();
    else
        passcode.show();
   
};

ProvisionerView.prototype.togglecert = function(e) {
    var select = $('form[name="modalProvisioner"] select[name="eap_type"]').first();
    var cert = select.closest('form').find('select[name="cert_type"]').closest('.control-group');
    var certpath_input = select.closest('form').find('input[name="ca_cert_path"]');
    var certpath = certpath_input.closest('.control-group');

    if  ($('#eap_type option:selected').text() == "PEAP"){
        certpath_input.val("");
        certpath.hide();
        cert.hide();
        }
    else{
        cert.show();
        certpath.show();
        }
};



