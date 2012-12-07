function initRoles() {
    /* Show a Role */
    $('#section').on('click', '[href*="#modalRole"]', function(event) {
        var modal = $('#modalRole');
        var url = $(this).attr('href');
        modal.empty();
        modal.modal({ shown: true });
        $.ajax(url)
            .done(function(data) {
                modal.append(data);
            })
            .fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#section h2'), obj.status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            });

        return false;
    });

    /* Create a role */
    $('#section').on('click', '#createRole', function(event) {
        var modal = $('#modalRole');
        var url = $(this).attr('href');
        modal.empty();
        modal.modal({ shown: true });
        $.ajax(url)
            .done(function(data) {
                modal.append(data);
                modal.on('shown', function() {
                    $('.chzn-select').chosen();
                    $('.chzn-deselect').chosen({allow_single_deselect: true});
                });
            })
            .fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#section h2'), obj.status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
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
        confirm_link.click(function() {
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
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError($('#section h2'), obj.status_msg);
                    $("body,html").animate({scrollTop:0}, 'fast');
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
                modal.modal('hide');
                modal.on('hidden', function() {
                    // Refresh the section
                    $('.sidebar-nav .nav-list .active a').trigger('click');
                });
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), obj.status_msg);
            });
        }

        return false;
    });
}
