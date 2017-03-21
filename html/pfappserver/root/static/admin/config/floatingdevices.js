/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    var items = new FloatingDevices();
    var view = new FloatingDeviceView({ items: items, parent: $('#section') });
});

/*
 * The FloatingDevices class defines the operations available from the controller.
 */
var FloatingDevices = function() {
};

FloatingDevices.prototype = new Items();

FloatingDevices.prototype.id  = '#floatingdevices';

FloatingDevices.prototype.formName  = 'modalFloatingDevice';

FloatingDevices.prototype.modalId   = '#modalFloatingDevice';

/*
 * The FloatingDeviceView class defines the DOM operations from the Web interface.
 */


var FloatingDeviceView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;

    // Show the tagged VLANs field when 'trunk port' is checked
    options.parent.on('change', 'form[name="modalFloatingDevice"] input[name="trunkPort"]', this.toggleTaggedVlan);

    // Initialize the tagged VLANs fields when displaying a floating device
    options.parent.on('show', '#modalFloatingDevice', function(e) {
        var checkbox = $('form[name="modalFloatingDevice"] input[name="trunkPort"]').first();
        $.proxy(that.toggleTaggedVlan, checkbox)(e);
    });
};

FloatingDeviceView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

FloatingDeviceView.prototype.constructor = FloatingDeviceView;

FloatingDeviceView.prototype.toggleTaggedVlan = function(e) {
    var checkbox = $(this);
    var taggedVlan = checkbox.closest('form').find('input[name="taggedVlan"]').first();

    if (checkbox.is(':checked'))
        taggedVlan.removeAttr('disabled');
    else
        taggedVlan.attr('disabled', 1);
};

