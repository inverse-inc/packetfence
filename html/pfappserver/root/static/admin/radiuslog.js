/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    $('#section').on('section.loaded', function(event) {
        $('#report_radius_audit_log .radiud_audit_log_datetimepicker a').click(function(event) {
            event.preventDefault();
            var a = $(event.currentTarget);
            $.ajax({
                url : a.attr('href'),
                type : 'POST'
            }).done(function(data){
                var start_date_input = $('#start_date');
                var start_time_input = $('#start_time');
                start_date_input.datepicker("setDate", data.time_offset.start.date);
                start_time_input.timepicker("setTime", data.time_offset.start.time);
                var end_date_input = $('#end_date');
                var end_time_input = $('#end_time');
                end_date_input.datepicker("setDate", data.time_offset.end.date);
                end_time_input.timepicker("setTime", data.time_offset.end.time);
            });
            return false;
        });
    });
});
