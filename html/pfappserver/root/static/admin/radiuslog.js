/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    $('#section').on('section.loaded', function(event) {
        $('#report_radius_audit_log .radiud_audit_log_datetimepicker a').click(function(event) {
            event.preventDefault();
            var a = event.currentTarget;
            var timespec = a.hash.replace(/^#last/,"");
            var amount = parseInt(/^\d+/.exec(timespec)[0]);
            var type = /[^\d]+$/.exec(timespec)[0];
            var milliseconds;
            if(type === "mins") {
                milliseconds = amount * 60 * 1000;
            } else if( type === "hours" || type === "hour" ) {
                milliseconds = amount * 60 * 60 * 1000;
            }
            var end_time = new Date();
            var start_time = new Date(end_time.getTime() - milliseconds);
            var start_date_input = $('#start_date');
            var start_time_input = $('#start_time');
            start_date_input.datepicker("setDate", start_time);
            start_time_input.timepicker("setTime",start_time.toTimeString());
            var end_date_input = $('#end_date');
            var end_time_input = $('#end_time');
            end_date_input.attr("value", "");
            end_time_input.attr("value", "");
            return false;
        });
    });
});
