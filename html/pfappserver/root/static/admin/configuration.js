function init() {

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
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
        }

        return false;
    });

    $('#section').on('section.loaded', function(event) {
        /* Set the focus on the first editable and visible field */
        $(':input:visible:enabled:first[name]').focus();
        /* Set the default value for compound controls*/
        $('.compound-input-btn-group .btn-group input').each(function (i,input) {
            var value = $(input).attr('value');
            var a = $(input).siblings('a[value="' + value  +  '"]');
            a.attr('default-value','yes');
        });

    });

    $('#section').on('reset', function(event) {
        $('.compound-input-btn-group .btn-group a[default-value="yes"]').click();
        return true;
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/configuration'));

    $(window).hashchange();

    activateNavLink();
}


