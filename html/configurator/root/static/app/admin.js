function registerExists() {
    $('#tracker a, .form-actions a').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function initStep() {

}

function saveStep(href) {
    $.ajax({
        type: 'POST',
        url: window.location.pathname,
        data: {'general.domain': $('#general_domain').val(),
               'general.hostname': $('#general_hostname').val(),
               'general.dhcpservers': $('#general_dhcpservers').val(),
               'alerting.emailaddr': $('#alerting_emailaddr').val()}
    }).done (function(data) {
        window.location.href = href;
    }).fail(function(jqXHR) {
        var obj = $.parseJSON(jqXHR.responseText);
        showError($('form'), obj.status_msg);
        $("body").animate({scrollTop:0}, 'fast');
    });

   return false;
}