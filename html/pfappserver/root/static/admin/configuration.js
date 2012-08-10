function init() {
    /* Register links in the sidebar list */
    $('.sidebar-nav .nav-list a').click(function(event) {
        var href = $(this).attr('href');
        var item = $(this).parent();
        var section = $('#section');
        $('.sidebar-nav .nav-list .active').removeClass('active');
        item.addClass('active');
        section.fadeOut('fast', function() {
            $(this).empty();
            $.ajax(href)
                .done(function(data) {
                    section.html(data);
                    section.fadeIn('fast', function() {
                        $('.datepicker').datepicker();
                        $('.chzn-select').chosen();
                        $('.btn-group .btn').click(function() {
                            $(this).button('toggle');
                            return false;
                        });
                    });
                })
                .fail(function(jqXHR) {
                    if (jqXHR.status == 401) {
                        // Unauthorized; redirect to URL specified in the location header
                        window.location.href = jqXHR.getResponseHeader('Location');
                    }
                    else {
                        var obj = $.parseJSON(jqXHR.responseText);
                        showError(section, obj.status_msg); // TODO : need inner div
                    }
                });
        });

        return false;
    });

    /* Load initial section */
    $('.sidebar-nav .nav-list a').first().trigger('click');
}