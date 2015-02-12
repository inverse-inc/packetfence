$(function() { // DOM ready
    var items = new FingerBankDevices();
    var view = new FingerBankDeviceView({ items: items, parent: $('#section') });
});

/*
 * The FingerBankDevices class defines the operations available from the controller.
 */
var FingerBankDevices = function() {
};

FingerBankDevices.prototype = new Items();

FingerBankDevices.prototype.id  = '#fingerbankdevices';

FingerBankDevices.prototype.formName  = 'modalFingerBankDevice';

FingerBankDevices.prototype.modalId   = '#modalFingerBankDevice';

/*
 * The FingerBankDeviceView class defines the DOM operations from the Web interface.
 */


var FingerBankDeviceView = function(options) {
    ItemView.call(this,options);
    var that = this;

};

FingerBankDeviceView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

FingerBankDeviceView.prototype.constructor = FingerBankDeviceView;
