function init() {
    /* Register links in the sidebar list */
    $('.sidebar-nav .nav-list a').click(function(event) {
        var item = $(this).parent();
        $('.sidebar-nav .nav-list .active').removeClass('active');
        item.addClass('active');
        return true;
    });

    /* Save a section */
    $('#section').on('submit', 'form[name="section"]', function(event) {
        var form = $(this);
        var url = form.attr('action');
        var valid = isFormValid(form);

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url,
                data: form.serialize()
            })
            .done(function(data) {
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert($('#section'));
                showSuccess($('form'), data.status_msg);
            })
            .fail(function(jqXHR) {
                if (jqXHR.status == 401) {
                    // Unauthorized; redirect to URL specified in the location header
                    window.location.href = jqXHR.getResponseHeader('Location');
                }
                else {
                    $("body,html").animate({scrollTop:0}, 'fast');
                    resetAlert($('#section'));
                    var status_msg;
                    try {
                        var obj = $.parseJSON(jqXHR.responseText);
                        status_msg = obj.status_msg;
                    }
                    catch(e) {
                        status_msg = "Cannot submit form";
                    }
                    showPermanentError($('form'), status_msg);
                }
            });
        }

        return false;
    });

    /* Load initial section */
    $('.sidebar-nav .nav-list .active a').trigger('click');
    /* Page refresh */
    $(window).hashchange(function(event) {
        var hash = location.hash;
        var href = '/configuration/' + hash.replace(/^#/,'');
        updateSection(href);
        return true;
    });
    $(window).hashchange();

    initAuthentication();
    initUsers();
    initViolations();
    initSoH();
    initRoles();
}
