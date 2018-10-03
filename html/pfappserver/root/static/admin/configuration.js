/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

function init() {

    /* Save a section */
    $('#section').on('submit', 'form[name="section"]', function(event) {
        var form = $(this);
        var url = form.attr('action');
        var valid = isFormValid(form);
        var btn = form.find('.btn-primary');

        if (valid) {
            btn.button('loading');
            $.ajax({
                type: 'POST',
                url: url,
                data: form.serialize()
            })
            .always(function() {
                btn.button('reset');
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert($('#section'));
            })
            .done(function(data) {
                showSuccess(form, data.status_msg);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
        }

        return false;
    });
    
    $('#section').on('click', '#testSMTPBtn', function(event) {
        event.preventDefault(); 
        var btn = $(this);
        var href = btn.attr('href');
        var modal = $('#testSMTPModal');
        var form = $('form[name="section"]');
        var valid = isFormValid(form);

        if (valid) {
            btn.button('loading');
            $.ajax({
                type: 'POST',
                url: href,
                data: form.serialize()
            })
            .always(function() {
                btn.button('reset');
                modal.modal('toggle');
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert($('#section'));
            })
            .done(function(data) {
                showSuccess(form, data.status_msg);
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
        }

        return false;
    });

    $('#section').on('section.loaded', function(event) {
        /* Set the focus on the first editable and visible field */
        $(':input:not(:disabled):not([readonly]):visible:enabled:first[name]').focus();
        /* Set the default value for compound controls */
        $('.compound-input-btn-group .btn-group input').each(function (i, input) {
            var value = $(input).attr('value');
            var a = $(input).siblings('a[value="' + value  +  '"]');
            a.attr('default-value','yes');
        });
        /* Load the first tab on section click */
        $('#tabView').find('[data-toggle="tab"]').first().tab('show');

    });

    $('#section').on('reset', function(event) {
        $('.compound-input-btn-group .btn-group a[default-value="yes"]').click();
        return true;
    });

    /* Show the tab content */
    $('#section').on('show', '[href="#newTabView"]', function(e) {
        var btn = $(e.target);
        var name = btn.attr("href");
        var target = $(name);
        var url = btn.attr("data-href");
        target.load(url, function() {
            target.find('.switch').bootstrapSwitch();
        });
        return true;
    });
    
    /* Automatically load first category */
    var href =  $('.sidenav-category a').first().attr('href');
    if (href) {
        href = href.replace(/^.*#/,"/");
    } else {
        href = "/configuration";
    }
    $(window).hashchange(pfOnHashChange(updateSection,href));

    $(window).hashchange();

    activateNavLink();
}

