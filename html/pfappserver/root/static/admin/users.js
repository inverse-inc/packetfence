function init() {
    /* Sort the search results */
    $('#section').on('click', 'thead a', function(event) {
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(url)
        .always(function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        })
        .done(function(data) {
            section.html(data);
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError(section, status_msg);
        });

        return false;
    });

    /* View a user (show the modal editor) */
    $('#section').on('click', '[href*="#modalUser"]', function(event) {
        var modal = $('#modalUser');
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        modal.empty();
        $.ajax(url)
            .always(function(){
                loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                modal.append(data);
                modal.modal({ shown: true });
                modal.one('shown', function() {
                    $('#pid').focus();
                });
            })
            .fail(function(jqXHR) {
                modal.modal('hide');
                $("body,html").animate({scrollTop:0}, 'fast');
                if (jqXHR.status == 404) {
                    $(window).hashchange();
                }
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Save a node (from the modal editor) */
    $('body').on('click', '#updateUser', function(event) {
        var btn = $(this),
        modal = $('#modalUser'),
        form = modal.find('form').first(),
        modal_body = modal.find('.modal-body'),
        url = $(this).attr('href'),
        valid = false;
        btn.button('loading');
        valid = isFormValid(form);
        if (valid) {
            $.ajax({
                type: 'POST',
                url: url,
                data: form.serialize()
            }).done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                btn.button('reset');
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });

    /* Delete a user (from the modal editor) */
    $('body').on('click', '#deleteUser', function(event) {
        var modal = $('#modalUser');
        var url = $(this).attr('href');
        $.ajax(url)
            .done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            });

        return false;
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/user/'));

    $(window).hashchange();
}
