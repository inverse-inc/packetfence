$(function(){
    $('#section').on('change', '#modalItem.syslogforwarded #all_logs', function(e) {
        var c = e.currentTarget;
        var logs_input = $('#logs');
        var control_group = logs_input.closest('div.control-group');
        if (c.checked) {
            console.log("checked");
            control_group.addClass("hidden");
        } else {
            control_group.removeClass("hidden");
        }
    });
});
