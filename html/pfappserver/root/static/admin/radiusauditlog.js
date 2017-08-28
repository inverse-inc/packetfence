/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    var items = new RadiusAuditLog();
    var view = new RadiusAuditLogView({ items: items, parent: $('#section') });
});

/*
 * The RadiusAuditLog class defines the operations available from the controller.
 */
var RadiusAuditLog = function() {
};

RadiusAuditLog.prototype = new Items();

RadiusAuditLog.prototype.id  = '#radiusAuditLog';

RadiusAuditLog.prototype.formName  = 'modalRadiusAuditLog';

RadiusAuditLog.prototype.modalId   = '#modalRadiusAuditLog';

RadiusAuditLog.prototype.createSelector = ".createRadiusAuditLog";

RadiusAuditLog.prototype.get = function(options) {
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

RadiusAuditLog.prototype.post = function(options) {
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
 * The RadiusAuditLogView class defines the DOM operations from the Web interface.
 */

var RadiusAuditLogView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
    var resetSearch = $.proxy(this.resetSearch, this);
    options.parent.on('click', '#radiuslog_reset', resetSearch);
};

RadiusAuditLogView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

RadiusAuditLogView.prototype.resetSearch = function(e) {
    e.preventDefault();
    var form = $('form[name="search"]');
    form.find('#start_date,#start_time,#end_date,#end_time').val('');
    form.find('select[name="per_page"]').val('25');
    form.find('select[name="all_or_any"]').val('all');
    $('#searchConditions').find('tbody').children(':not(.hidden)').find('[href="#delete"]').click();
    form.submit();
};
