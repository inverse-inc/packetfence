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
    // Display sub children
    var showChildren = $.proxy(this.showChildren, this);
    options.parent.on('click', '#fingerbankdevices [href$="/children"]', showChildren);
    options.parent.on('show hidden','.collapse',function(event) {
        var that = $(this);
        var tr = that.closest('tr').first();
        tr.toggleClass('hidden');
        event.stopPropagation(); //To stop the event from closing parents
    });

};

FingerBankDeviceView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

FingerBankDeviceView.prototype.constructor = FingerBankDeviceView;

FingerBankDeviceView.prototype.showChildren = function(e) {
    var that = this;
    var link = $(e.currentTarget);
    var href = link.attr("href");
    var target = link.attr("data-target");
    console.log(target);
    var children_div = $(target);
    var row = children_div.closest("tr");
    children_div.collapse({toggle: false});
    if(row.hasClass('hidden')) {
        this.items.get({
            url: href,
            success: function(data) {
                children_div.find('table').html(data);
                children_div.collapse('show');
            },
            errorSibling: $(that.id)
        });
    } else {
        children_div.collapse('hide');
    }

    return false;
};
