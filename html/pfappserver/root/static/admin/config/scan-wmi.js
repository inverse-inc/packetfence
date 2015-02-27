$(function() { // DOM ready
    var items = new ScanWMIRules();
    var view = new ScanWMIRuleView({ items: items, parent: $('#section') });
});

/*
 * The ScanWMIRules class defines the operations available from the controller.
 */
var ScanWMIRules = function() {
};

ScanWMIRules.prototype = new Items();

/*
 * The ScanWMIRuleView class defines the DOM operations from the Web interface.
 */

var ScanWMIRuleView = function(options) {
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
    options.parent.on('click', '#wmi_rulesEmpty [href=#add]', function(event) {
        $('#wmi_rules').trigger('addrow');
        $('#wmi_rulesEmpty').addClass('hidden');
        return false;
    });
};

