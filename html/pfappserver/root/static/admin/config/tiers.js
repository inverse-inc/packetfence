$(function() { // DOM ready
    var items = new Tiers();
    var view = new TiersView({ items: items, parent: $('#section') });
});

/*
 * The Tiers class defines the operations available from the controller.
 */
var Tiers = function() {
};

Tiers.prototype = new Items();

/*
 * The ScanWMIRuleView class defines the DOM operations from the Web interface.
 */

var TiersView = function(options) {
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
    options.parent.on('click', '#tiersEmpty [href=#add]', function(event) {
        $('#tiers').trigger('addrow');
        $('#tiersEmpty').addClass('hidden');
        return false;
    });
};
