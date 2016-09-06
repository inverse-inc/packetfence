$(function() { // DOM ready
    var items = new DynamicReport();
    var view = new DynamicReportView({ items: items, parent: $('#section') });
});

/*
 * The DynamicReport class defines the operations available from the controller.
 */
var DynamicReport = function() {
};

DynamicReport.prototype = new Items();

DynamicReport.prototype.id  = '#dynamicReport';

DynamicReport.prototype.formName  = 'modalDynamicReport';

DynamicReport.prototype.modalId   = '#modalDynamicReport';

DynamicReport.prototype.get = function(options) {
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

DynamicReport.prototype.post = function(options) {
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

/*
 * The DynamicReportView class defines the DOM operations from the Web interface.
 */


var DynamicReportView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
};

DynamicReportView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

