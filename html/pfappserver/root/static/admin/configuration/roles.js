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

    /* Delete a Role */
    $('#section').on('click', '[href*="#deleteRole"]', function(event) {
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var name = row.find('td a[href*="#modalRole"]').html();
        var modal = $('#deleteRole');
        var confirm_link = modal.find('a.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal({ show: true });
        confirm_link.off('click');
        confirm_link.click(function(e) {
            e.preventDefault();
            $.ajax(url)
                .always(function() {
                    modal.modal('hide');
                })
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    if (table.find('tbody tr').length == 0) {
                        // No more filters
                        table.remove();
                        $('#noRole').removeClass('hidden');
                    }
                })
                .fail(function(jqXHR) {
                    $("body,html").animate({scrollTop:0}, 'fast');
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section table'), status_msg);
                });
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
