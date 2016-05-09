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

