$(function() { // DOM ready
    var items = new FingerbankDevices();
    var view = new FingerbankDeviceView({ items: items, parent: $('#section') });
});

/*
 * The FingerbankDevices class defines the operations available from the controller.
 */
var FingerbankDevices = function() {
};

FingerbankDevices.prototype = new Items();

FingerbankDevices.prototype.id  = '#fingerbankdevices';

FingerbankDevices.prototype.formName  = 'modalFingerbankDevice';

FingerbankDevices.prototype.modalId   = '#modalFingerbankDevice';

/*
 * The FingerbankDeviceView class defines the DOM operations from the Web interface.
 */


var FingerbankDeviceView = function(options) {
    ItemView.call(this,options);
    var that = this;
    // Display sub children
    var showChildren = $.proxy(this.showChildren, this);
    options.parent.on('click', '#fingerbankdevices [href$="/children"]', showChildren);
    var read = $.proxy(this.readItem, this);
    options.parent.on('click', '#fingerbankdevices [href$="/add_child"], ', read);
    options.parent.on('show hidden','.collapse',function(event) {
        var that = $(this);
        var tr = that.closest('tr').first();
        tr.toggleClass('hidden');
        event.stopPropagation(); //To stop the event from closing parents
    });

};

FingerbankDeviceView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

FingerbankDeviceView.prototype.constructor = FingerbankDeviceView;

FingerbankDeviceView.prototype.showChildren = function(e) {
    var that = this;
    var link = $(e.currentTarget);
    var href = link.attr("href");
    var target = link.attr("data-target");
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
