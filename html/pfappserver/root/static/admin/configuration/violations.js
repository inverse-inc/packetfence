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

    /* Modal Editor: create or modify a violation */
    $('body').on('submit', 'form[name="violation"]', function(event) {
        var form = $(this);
        var modal = $('#modalViolation');
        var valid = true;
        var data = {};
        var tab;

        // Validate the form sequentialy, tab by tab, and stop as soon as a
        // field is invalid
        $.each(['Definition', 'Triggers', 'Remediation', 'Advanced'], function(index, value) {
            var tab = '#violation' + value;
            form.find(tab + ' input[name], ' + tab + ' select, ' + tab + ' .btn-group').each(function() {
                var input = $(this);
                if (input.attr('type') == 'checkbox') {
                    data[input.attr('name')] = input.is(':checked');
                }
                else if (input.attr('name') == 'priority') {
                    if (isFormInputEmpty(input) || isInvalidNumber(input, 1, 10)) {
                        valid = false;
                        return false;
                    }
                    else {
                        data['priority'] = input.val();
                    }
                }
                else if (input.attr('name') == 'max_enable') {
                    if (isFormInputEmpty(input) || isInvalidNumber(input, 0, 10)) {
                        valid = false;
                        return false;
                    }
                    else {
                        data['max_enable'] = input.val();
                    }
                }
                else if (input.hasClass('btn-group')) {
                    if (isFormInputEmpty(input))
                        valid = false;
                    else {
                        // Append time unit
                        var btn = input.find('a.active');
                        var matches = btn.attr('name').match(/(.+?)_unit/);
                        if (matches) {
                            data[matches[1]] += btn.attr('value');
                        }
                    }
                }
                else if (input.hasClass('onoffswitch-checkbox')) {
                    var isOn = switchIsOn(input);
                    data[input.attr('name')] = isOn;
                }
                else {
                    if (isFormInputEmpty(input))
                        valid = false;
                    else
                        data[input.attr('name')] = input.val();
                }
                if (!valid)
                    return false;
            });
            if (!valid)
                return false;

        });
        if (!valid)
            return false;

        if (valid) {
            var violation_id = form.find('input[name="id"]');
            if (violation_id.length) {
                data['id'] = violation_id.val();
            }
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
                showError(form.find('.modal-body'), obj.status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            });
        }

        return false;
    });
}