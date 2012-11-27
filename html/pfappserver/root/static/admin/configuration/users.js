function initUsers() {

    /* Create user(s) */
    $('#section').on('submit', 'form[name="users"]', function(event) {
        var form = $(this),
        btn = form.find('[type="submit"]'),
        valid;

        // Don't submit inputs from hidden rows and tabs.
        // The functions isFormValid and serialize will ignore disabled inputs.
        form.find('tr.hidden :input, .tab-pane:not(.active) :input').attr('disabled', 'disabled');

        // Identify the type of creation (single, multiple or import) from the selected tab
        form.find('input[name="type"]').val($('.nav-tabs .active a').attr('href').substring(1));
        valid = isFormValid(form);

        if (valid) {
            btn.button('loading');
            resetAlert($('#section'));

            // Since we can be uploading a file, the form target is an iframe from which
            // we read the JSON returned by the server.
            var iform = $("#iframe_form");
            iform.one('load', function(event) {
                // Restore disabled inputs
                form.find('tr.hidden :input, .tab-pane:not(.active) :input').removeAttr('disabled');
                
                $("body,html").animate({scrollTop:0}, 'fast');
                btn.button('reset');
                var body = $(this).contents().find('body');
                if (body.find('form').length) {
                    // We received a HTML form
                    var modal = $('#modalPasswords');
                    modal.empty();
                    modal.append(body.children());
                    modal.modal({ backdrop: 'static', shown: true });
                }
                else {
                    // We received JSON
                    var data = $.parseJSON(body.text());
                    if (data.status < 300)
                        showPermanentSuccess(form, data.status_msg);
                    else
                        showPermanentError(form, data.status_msg);
                }
            });
        }
        else {
            // Restore disabled inputs
            form.find('tr.hidden :input, .tab-pane:not(.active) :input').removeAttr('disabled');
        }

        return valid;
    });

    /* Disable checked columns from import tab since they are required */
    $('#section').on('section.loaded', function(event) {
        $('#columns :checked').attr('disabled', 'disabled');
    });

    /* Print passwords */
    $('#section').on('click', '#modalPasswords a[href$="print"]', function(event) {
        var btn = $(this);
        var form = btn.closest('form');
        form.attr('action', btn.attr('href'));
        form.attr('target', '_blank');
        form.submit();

        return false;
    });

    /* Send passwords by email */
    $('#section').on('click', '#modalPasswords a[href$="mail"]', function(event) {
        var btn = $(this);
        var form = btn.closest('form');
        var modal_body = form.find('.modal-body');

        btn.button('loading');
        $.ajax({
            type: 'POST',
            url: btn.attr('href'),
            data: form.serialize()
        })
        .done(function(data) {
            $("body,html").animate({scrollTop:0}, 'fast');
            btn.button('reset');
            resetAlert(modal_body);
            showSuccess(modal_body.children().first(), data.status_msg);
        })
        .fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                var obj = $.parseJSON(jqXHR.responseText);
                btn.button('reset');
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), obj.status_msg);
            }
        });
    
        return false;
    });
}