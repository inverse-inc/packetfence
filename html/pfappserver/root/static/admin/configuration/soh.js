function initSoH() {
    /* Show a SoH filter */
    $('#section').on('click', '[href*="#modalFilter"]', function(event) {
        var modal = $('#modalFilter');
        var url = $(this).attr('href');
        modal.empty();
        modal.modal({ shown: true });
        $.ajax(url)
            .done(function(data) {
                modal.append(data);
            })
            .fail(function(jqXHR) {
                if (jqXHR.status == 401) {
                    // Unauthorized; redirect to URL specified in the location header
                    window.location.href = jqXHR.getResponseHeader('Location');
                }
                else {
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError($('#section h2'), obj.status_msg);
                    $("body,html").animate({scrollTop:0}, 'fast');
                }
            });

        return false;
    });

    /* Create a SoH filter */
    $('#section').on('click', '#createFilter', function(event) {
        var modal = $('#modalFilter');
        var url = $(this).attr('href');
        modal.empty();
        modal.modal({ shown: true });
        $.ajax(url)
            .done(function(data) {
                modal.append(data);
            })
            .fail(function(jqXHR) {
                if (jqXHR.status == 401) {
                    // Unauthorized; redirect to URL specified in the location header
                    window.location.href = jqXHR.getResponseHeader('Location');
                }
                else {
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError($('#section h2'), obj.status_msg);
                    $("body,html").animate({scrollTop:0}, 'fast');
                }
            });

        return false;    
    });

    /* Delete a SoH filter */
    $('#section').on('click', '[href*="#deleteFilter"]', function(event) {
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var name = row.find('td a[href*="#modalFilter"]').html();
        var modal = $('#deleteFilter');
        var confirm_link = modal.find('a.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal({ show: true });
        confirm_link.off('click');
        confirm_link.click(function() {
            $.ajax(url)
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    if (table.find('tbody tr').length == 0) {
                        // No more filters
                        table.remove();
                        $('#noFilter').removeClass('hidden');
                    }
                    modal.modal('hide');
                })
                .fail(function(jqXHR) {
                    if (jqXHR.status == 401) {
                        // Unauthorized; redirect to URL specified in the location header
                        window.location.href = jqXHR.getResponseHeader('Location');
                    }
                    else {
                        var obj = $.parseJSON(jqXHR.responseText);
                        modal.modal('hide');
                        showError($('#section h2'), obj.status_msg);
                        $("body,html").animate({scrollTop:0}, 'fast');
                    }
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

    /* Modal Editor: add or delete a rule */
    $('body').on('click', '[href="#addRule"]', function(event) {
        var rows = $(this).closest('tbody').children();
        var row_model = rows.filter('.hidden').first();
        var row = row_model.clone();
        row.removeClass('hidden');
        row.insertBefore(rows.last());
    });
    $('body').on('click', '[href="#deleteRule"]', function(event) {
        if (!$(this).hasClass('disabled'))
            $(this).closest('tr').fadeOut('fast', function() { $(this).remove() });
    });

    /* Modal Editor: create or modify a filter */
    $('body').on('submit', 'form[name="filter"]', function(event) {
        var form = $(this);
        var modal = $('#modalFilter');
        var valid = true;
        var data = {};
        form.find('.control-group input:text').each(function() {
            var input = $(this);
            if (isFormInputEmpty(input))
                valid = false;
            else
                data[input.attr('name')] = input.val();
        });
        if (valid) {
            data['action'] = form.find('select[name="action"]').val();
            if (data['action'] == 'violation')
                data['vid'] = form.find('select[name="vid"]').val();
            data['rules'] = [];
            form.find('.filterRule:not(.hidden)').each(function() {
                var row = $(this);
                data['rules'].push([ row.find('select[name="rule"]').val(),
                                     row.find('select[name="op"]').val(),
                                     row.find('select[name="status"]').val() ]);
            });
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: {json: $.toJSON(data)}
            }).done(function() {
                modal.modal('hide');
                modal.on('hidden', function() {
                    // Refresh the section
                    $('.sidebar-nav .nav-list .active a').trigger('click');
                });
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(form, obj.status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            });
        }

        return false;
    });
}