/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

/* Show a Role */
    $('#section').on('click', '[href*="#modalRole"]', function(event) {
        var modal = $('#modalRole');
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
                modal.one('shown', function() {
                    $('#name').focus();
                });
                modal.modal({ shown: true });
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section table'), status_msg);
            });

        return false;
    });

    /* Create a role */
    $('#section').on('click', '#createRole', function(event) {
        var modal = $('#modalRole');
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
                modal.one('shown', function() {
                    $('#name').focus();
                    $('.chzn-select').chosen();
                    $('.chzn-deselect').chosen({allow_single_deselect: true});
                });
                modal.modal({ shown: true });
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section table'), status_msg);
            });

        return false;
    });

    /* Modal Editor: save a role */
    $('body').on('submit', 'form[name="role"]', function(event) {
        var form = $(this),
        modal = $('#modalRole'),
        modal_body = modal.find('.modal-body'),
        valid = isFormValid(form);

        if (valid) {
            resetAlert(modal_body);
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).done(function() {
                modal.on('hidden', function() {
                    // Refresh the section
                    $(window).hashchange();
                });
                modal.modal('hide');
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });
