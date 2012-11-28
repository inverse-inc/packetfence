function init() {
    /* Register links in the sidebar list */
/*
    $('.sidebar-nav .nav-list a').click(function(event) {
        var href = $(this).attr('href');
        var item = $(this).parent();
        var section = $('#section');
        var loader = section.prev('.loader');
        $('.sidebar-nav .nav-list .active').removeClass('active');
        item.addClass('active');
        section.fadeOut('fast', function() {
            $("body,html").animate({scrollTop:0}, 'fast');
            loader.show();
            $(this).empty();
            $.ajax(href)
                .done(function(data) {
                    section.html(data);
                    loader.hide();
                    section.fadeIn('fast', function() {
                        $('.datepicker').datepicker({ autoclose: true });
                        $('.chzn-select').chosen();
                        $('.chzn-deselect').chosen({allow_single_deselect: true});
                        $(':input:visible:enabled:first').focus();
                        section.trigger('section.loaded');
                    });
                })
                .fail(function(jqXHR) {
                    if (jqXHR.status == 401) {
                        // Unauthorized; redirect to URL specified in the location header
                        window.location.href = jqXHR.getResponseHeader('Location');
                    }
                    else {
                        var obj = $.parseJSON(jqXHR.responseText);
                        loader.hide();
                        section.append('<div></div>').fadeIn();
                        showError(section.children().first(), obj.status_msg);
                    }
                });
        });

        return false;
    });
*/

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
                    var obj = $.parseJSON(jqXHR.responseText);
                    $("body,html").animate({scrollTop:0}, 'fast');
                    resetAlert($('#section'));
                    showPermanentError($('form'), obj.status_msg);
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
        if(hash == '') {
            hash = '#/configuration/general';
        }
        var href =  hash.replace(/^#/,'') + location.search ;
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
