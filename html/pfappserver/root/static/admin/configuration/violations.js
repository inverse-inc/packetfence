function initViolations() {
    /* Show a violation */
    $('#section').on('click', '[href*="#modalViolation"]', function(event) {
        var modal = $('#modalViolation');
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

    /* Create a violation */
    $('#section').on('click', '#createViolation', function(event) {
        var modal = $('#modalViolation');
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

    /* Delete a violation */
    $('#section').on('click', '[href*="#deleteViolation"]', function(event) {
        if ($(this).hasClass('disabled'))
            return false;
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var cells = row.find('td');
        var name = $(cells[1]).text();
        if (!name) name = $(cells[0]).text();
        var modal = $('#deleteViolation');
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
                        // No more violations
                        table.remove();
                        $('#noViolation').removeClass('hidden');
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

    /* Modal Editor: add a trigger */
    $('body').on('click', '[href="#addTrigger"]', function(event) {
        var id = $(this).prev().val();
        var type = $(this).prev().prev().val();
        var name = type + "::" + id;
        var select = $('#trigger');
        var last = true;
        select.find('option').each(function() {
            if ($(this).val() > name) {
                $('<option value="' + name + '" selected="selected">' + name + '</option>').insertBefore(this);
                last = false;
                return false;
            }
        });
        if (last)
            select.append('<option value="' + name + '" selected="selected">' + name + '</option>');
        select.trigger("liszt:updated");
    });

    /* Modal Editor: save a violation */
    $('body').on('submit', 'form[name="violation"]', function(event) {
        var form = $(this),
        modal = $('#modalViolation'),
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

    /* Preview a violation's remediation page */
    $('#section').on('click', '[href*="#previewPage"]', function(event) {
        var modal = $('#modalViolation');
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
}