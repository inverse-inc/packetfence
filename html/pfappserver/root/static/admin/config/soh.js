    /* Show a SoH filter */
    $('#section').on('click', '[href*="#modalFilter"]', function(event) {
        var modal = $('#modalFilter');
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
                modal.on('shown', function() {
                    modal.find('select[name="action"]').trigger('change');
                });
                modal.modal({ shown: true });
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Create a SoH filter */
    $('#section').on('click', '#createFilter', function(event) {
        var modal = $('#modalFilter');
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
                    $('#filterName').focus();
                });
                modal.modal({ shown: true });
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Delete a SoH filter */
    $('#section').on('click', '[href*="#deleteFilter"]', function(e) {
        e.preventDefault();

        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var name = row.find('td a[href*="#modalFilter"]').html();
        var modal = $('#deleteFilter');
        var confirm_btn = modal.find('.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal({ show: true });
        confirm_btn.off('click');
        confirm_btn.click(function(e) {
            e.preventDefault();
            confirm_btn.button('loading');
            $.ajax(url)
                .always(function() {
                    modal.modal('hide');
                    confirm_btn.button('reset');
                })
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    if (table.find('tbody tr').length == 0) {
                        // No more filters
                        table.remove();
                        $('#noFilter').removeClass('hidden');
                    }
                })
                .fail(function(jqXHR) {
                    $("body,html").animate({scrollTop:0}, 'fast');
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section h2'), status_msg);
                });
        });

        return false;
    });

    /* Modal Editor: display or hide the violation pull down menu */
    $('body').on('change', 'select[name="action"]', function (event) {
        // Not using 'chosen' for the moment as it has glitches when used in a modal
        if ($(this).val() == 'violation')
            $('select[name="vid"]').fadeIn('fast');
        else
            $('select[name="vid"]').fadeOut('fast');

        return true;
    });

    /* Modal Editor: add a condition */
    $('body').on('click', '[href="#addRule"]', function(event) {
        var rows = $(this).closest('tbody').children();
        var row_model = rows.filter('.hidden').first();
        var row = row_model.clone();
        row.removeClass('hidden');
        row.insertBefore(rows.last());
    });

    /* Modal Editor: create or modify a filter */
    $('body').on('submit', 'form[name="filter"]', function(e) {
        e.preventDefault();

        var form = $(this);
        var modal = $('#modalFilter');
        var modal_body = modal.find('.modal-body');
        var btn = modal.find('.btn-primary').first();
        var valid = isFormValid(form);
        if (valid) {
            // Don't submit hidden/template rows -- serialize will ignore disabled inputs
            form.find('tr.hidden :input').attr('disabled', 'disabled');
            btn.button('loading');
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).always(function() {
                btn.button('reset');
            }).done(function() {
                modal.on('hidden', function() {
                    // Refresh the section
                    $(window).hashchange();
                });
                modal.modal('hide');
            }).fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError(modal_body.children().first(), status_msg);
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
            });
        }

        return false;
    });
