function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        saveStep(href);
        return false; // don't follow link
    });
}

function initStep() {
    $('#general_domain').focus();
}

function saveStep(href) {
    var valid = true;

    $('form[name="config"] .control-group').each(function(index) {
        var e = $(this);
        var i = e.find('input, textarea').first();
        if (i.length) {
            if ($.trim(i.val()).length == 0) {
                e.addClass('error');
                valid = false;
            }
            else
                e.removeClass('error');
        }
    });
    if (valid) {
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: {'general.domain': $('#general_domain').val(),
                   'general.hostname': $('#general_hostname').val(),
                   'general.dhcpservers': $('#general_dhcpservers').val(),
                   'alerting.emailaddr': $('#alerting_emailaddr').val(),
                   'advanced.hash_passwords': $('input[name="advanced.hash_passwords"]:checked').val()}
        }).done (function(data) {
            window.location.href = href;
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('form[name="config"]'), obj.status_msg);
            $("body,html").animate({scrollTop:0}, 'fast');
        });
    }
    else {
        var form = $('form[name="config"]');
        resetAlert(form.parent());
        showError(form, 'Please verify your configuration.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }

    return false;
}
