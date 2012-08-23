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
                        section.append('<div></div>').fadeIn();
                        showError(section.children().first(), obj.status_msg);
                    }
                });
        });

        return false;
    });

    /* Save a section */
    $('#section').on('submit', 'form[name="section"]', function(event) {
        var url = $(this).attr('action');
        var data = {};
        // Extract values from inputs, textareas, selects and buttons (time units)
        $(this).find('input:text, textarea, select, button.active').each(function () {
            if (this.name.length > 0) {
                var val = $(this).val();
                data[this.name] = $.isArray(val)? val.join(',') : val;
            }
        });
        // Extract values from checkboxes
        $(this).find('input:checkbox').each(function () {
            if (this.name.length > 0) {
                var val = this.checked? $(this).val() : '';
                data[this.name] = val;
            }
        });
        $.ajax({
            type: 'POST',
            url: url,
            data: data
        })
        .done(function(data) {
            $("body,html").animate({scrollTop:0}, 'fast');
            resetAlert($('h3'));
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
                showPermanentError($('form'), obj.status_msg);
            }
        });

        return false;
    });

    /* Load initial section */
    $('.sidebar-nav .nav-list .active a').trigger('click');

    initSoH();
}