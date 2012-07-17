$(function () {
    $('.datepicker').datepicker({
        endDate: new Date() // today
    });

    /* Initial search */
    $.ajax('/node/search')
        .done(function(data) {
            var results = $('#results');
            results.html(data);
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#results'), obj.status_msg);
        });
});