function initAuthentication() {
    /* View a user source */
    function readSource(event, url) {
        var section = $('#section');
        var href = url || $(this).attr('href');
        section.fadeOut('fast', function() {
            $("body,html").animate({scrollTop:0}, 'fast');
            $(this).empty();
            $.ajax(href)
                .done(function(data) {
                    section.html(data);
                    section.fadeIn('fast', function() {
                        $('.chzn-select').chosen();
                        //$('.chzn-deselect').chosen({allow_single_deselect: true});
                    });
                })
                .fail(function(jqXHR) {
                    if (jqXHR.status == 401) {
                        // Unauthorized; redirect to URL specified in the location header
                        window.location.href = jqXHR.getResponseHeader('Location');
                    }
                    else {
                        var obj = $.parseJSON(jqXHR.responseText);
                        section.append('<div></div>').fadeIn();
                        showError(section.children().first(), obj.status_msg);
                    }
                });
        });

        return false;
    }

    /* Reset and create button */
    $('#section').on('click', '[href*="#readSource"], #createSource a', function(event) {
        var _readSource = $.proxy(readSource, this);
        return _readSource(event);
    });

    /* Delete a source */
    $('#section').on('click', '[href*="#deleteSource"]', function(event) {
        if ($(this).hasClass('disabled'))
            return false;
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var name = row.find('[href*="readSource"]').first().text();
        var modal = $('#deleteSource');
        var confirm_link = modal.find('a.btn-primary').first();
        modal.find('h3 span').html(name);
        modal.modal({ show: true });
        confirm_link.off('click');
        confirm_link.click(function() {
            $.ajax(url)
                .done(function(data) {
                    row.remove();
                    var table = $('#section table');
                    var rows = table.find('tbody tr:not(.hidden)');
                    if (rows.find('.sort-handle').length == 0) {
                        // No more user sources
                        table.remove();
                        $('#noSource').removeClass('hidden');
                    }
                    else {
                        updateSortableTable(rows);
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

    /* Save a source */
    $('#section').on('submit', 'form[name="source"]', function(event) {
        var form = $(this),
        valid = isFormValid(form);

        if (valid) {
            resetAlert($('#section'));
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).done(function(data) {
                $('#section').fadeOut('fast', function() {
                    // Refresh the complete section
                    $(this).empty();
                    $(this).html(data);
                    $(this).fadeIn('fast', function() {
                        $('.chzn-select').chosen();
                    });
                });
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showPermanentError(form, obj.status_msg);
            });
        }

        return false;
    });

    /* Initial creation of a condition when no condition is defined */
    $('body').on('click', '#ruleConditionsEmpty [href="#add"]', function(event) {
        var tbody = $('#ruleConditions').children('tbody');
        var row_model = tbody.children('.hidden').first();
        if (row_model) {
            $('#ruleConditionsEmpty').addClass('hidden');
            var row_new = row_model.clone();
            row_new.removeClass('hidden');
            row_new.insertBefore(row_model);
        }
    });

    /* Show a rule */
    $('#section').on('click', '#sourceRules a:not(.btn-icon)', function(event) {
        var modal = $('#modalRule');
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

    /* Create a rule */
    $('#section').on('click', '#createRule', function(event) {
        var modal = $('#modalRule');
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

    /* Save a rule */
    $('#section').on('submit', 'form[name="rule"]', function(event) {
        var form = $(this),
        modal = $('#modalRule'),
        modal_body = modal.find('.modal-body').first(),
        valid = isFormValid(form);

        if (valid) {
            resetAlert(modal_body);
            // Don't submit hidden/template rows
            form.find('tr.hidden :input').attr('disabled', 'disabled');
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    // Refresh the complete section
                    $('#section').fadeOut('fast', function() {
                        $(this).empty();
                        $(this).html(data);
                        $(this).fadeIn('fast', function() {
                            $('.chzn-select').chosen();
                        });
                    });
                });
            }).fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showPermanentError(modal_body.children().first(), obj.status_msg);
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
            });
        }

        return false;
    });
}