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
            .always(function() {
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert($('#section'));
            })
            .done(function(data) {
                showSuccess(form, data.status_msg);
            })
            .fail(function(jqXHR) {
                var status_msg;
                try {
                    var obj = $.parseJSON(jqXHR.responseText);
                    status_msg = obj.status_msg;
                }
                catch(e) {
                    status_msg = "Cannot submit form";
                }
                showPermanentError(form, status_msg);
            });
        }

        return false;
    });

    /* Set the focus on the first editable and visible field */
    $('#section').on('section.loaded', function(event) {
        $(':input:visible:enabled:first').focus();
    });

    $(window).hashchange(pfOnHashChange('/',updateSection,'/configuration'));

    $(window).hashchange();

    activate_nav_link();


    initAuthentication();
    initUsers();
    initViolations();
    initSoH();
    initRoles();
}
