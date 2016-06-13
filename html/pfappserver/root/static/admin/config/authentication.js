$(function() { // DOM ready

    /* Delete a source */
    $('#section').on('click', '.sources [href*="/delete"]', function(event) {
        if ($(this).hasClass('disabled'))
            return false;
        var url = $(this).attr('href');
        var row = $(this).closest('tr');
        var name = row.find('[href*="/read"]').first().text();
        var modal = $('#deleteSource');
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
                    $(window).hashchange();
                })
                .fail(function(jqXHR) {
                    $("body,html").animate({scrollTop:0}, 'fast');
                    var status_msg = getStatusMsg(jqXHR);
                    showError($('#section h2'), status_msg);
                });
            return false;
        });

        return false;
    });

    /* Test a source */
    $('#section').on('click', '#testSource', function(e) {
        e.preventDefault();

        var btn = $(this);
        var form = btn.closest('form');
        var valid = isFormValid(form);

        resetAlert($('#section'));
        if (valid) {
            $.ajax({
                type: 'POST',
                url: btn.attr('href'),
                data: form.serialize()
            }).done(function(data) {
                showSuccess(form, data.status_msg);
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
        }
    });

    /* Create a source */
    $('#section').on('submit', 'form[name="create_source"]', function(e) {
        e.preventDefault();

        var form = $(this),
            valid = isFormValid(form);

        if (valid) {
            resetAlert($('#section'));
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).done(function(data, textStatus, jqXHR) {
                location.hash = jqXHR.getResponseHeader('Location');
            }).fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
            // TODO: find a way to change the location hash without reloading the page
            // location.hash = 'authentication';
        }
    });

    /* Save a source */
    $('#section').on('submit', 'form[name="source"]', function(e) {
        e.preventDefault();

        var form = $(this),
        btn = form.find('.btn-primary'),
        valid = isFormValid(form);

        if (valid) {
            btn.button('loading');
            resetAlert($('#section'));
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).always(function() {
                btn.button('reset');
            }).done(function(data, textStatus, jqXHR) {
                $('#section').fadeOut('fast', function() {
                    // Refresh the complete section
                    $(this).empty();
                    $(this).html(data);
                    $(this).fadeIn('fast', function() {
                        $('.chzn-select').chosen();
                        $('#id').focus();
                    });
                });
            }).fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(form, status_msg);
            });
            // TODO: find a way to change the location hash without reloading the page
            // location.hash = 'authentication';
        }
    });

    /* Show a rule */
    $('#section').on('click', '#sourceRules a:not(.btn-icon)', function(event) {
        var modal = $('#modalRule');
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
                    $('#id').focus();
                });
                modal.modal({ shown: true });

                var rule_class = $('#class');
                var actions_table = $('#ruleActions');
                var action_row = actions_table.children('tbody').children('tr');
                if (rule_class.find(':selected').attr('value') == 'administration') {
                    action_row.find('option[data-rule-class="administration"]').removeClass('hidden');
                    action_row.find('option[data-rule-class="authentication"]').addClass('hidden');
                } else if (rule_class.find(':selected').attr('value') == 'authentication') {
                    action_row.find('option[data-rule-class="authentication"]').removeClass('hidden');
                    action_row.find('option[data-rule-class="administration"]').addClass('hidden');
                }

            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h3'), status_msg);
            });

        return false;
    });

    /* Create a rule */
    $('#section').on('click', '#createRule', function(event) {
        var modal = $('#modalRule');
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
                    $('#id').focus();
                    $('#class').trigger("change");
                });
                modal.modal({ shown: true });
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h3'), status_msg);
            });

        return false;
    });

    /* Save a rule */
    $('#section').on('submit', 'form[name="rule"]', function(event) {
        var form = $(this),
        btn = form.find('.btn-primary'),
        modal = $('#modalRule'),
        modal_body = modal.find('.modal-body').first(),
        valid = isFormValid(form);

        if (valid) {
            btn.button('loading');
            resetAlert(modal_body);
            // Don't submit hidden/template rows -- serialize will ignore disabled inputs
            form.find('tr.hidden :input').attr('disabled', 'disabled');
            $.ajax({
                type: 'POST',
                url: form.attr('action'),
                data: form.serialize()
            }).always(function() {
                btn.button('reset');
            }).done(function(data) {
                modal.one('hidden', function() {
                    // Refresh the rules list
                    $('#sourceRulesEmpty').closest('.control-group').fadeOut('fast', function() {
                        $(this).empty();
                        $(this).html(data);
                        $(this).fadeIn('fast', function() {
                            $('.chzn-select').chosen();
                        });
                    });
                });
                modal.modal('hide');
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(modal_body.children().first(), status_msg);
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
            });
        }

        return false;
    });

    /* Update available and configured actions when selecting a rule class */
    $('#section').on('change', '#class', function(event) {
        var that = $(this);
        var table = $('#ruleActions');

        table.find('tr:not(.hidden)').remove();

        var row_model = table.children('tbody').children('.hidden').first();
        if (that.find(':selected').attr('value') == 'administration') {
            row_model.find('option[data-rule-class="administration"]').removeClass('hidden');
            row_model.find('option[data-rule-class="administration"]').removeAttr('disabled');
            row_model.find('option[data-rule-class="authentication"]').addClass('hidden');
            row_model.find('option[data-rule-class="authentication"]').attr('disabled', 'disabled');
        } else if (that.find(':selected').attr('value') == 'authentication') {
            row_model.find('option[data-rule-class="authentication"]').removeClass('hidden');
            row_model.find('option[data-rule-class="authentication"]').removeAttr('disabled');
            row_model.find('option[data-rule-class="administration"]').addClass('hidden');
            row_model.find('option[data-rule-class="administration"]').attr('disabled', 'disabled');
        }

        $('#ruleActions tr:not(.hidden) select[name$=type]').each(function() {
            updateAction($(this), false);
        });
        table.trigger("addrow");
        table.find('tr').find('[href="#delete"]').addClass('hidden');

    });

    /* Initial creation of a rule condition when no condition is defined */
    $('body').on('click', '#ruleConditionsEmpty [href="#add"]', function(event) {
        $('#ruleConditions').trigger("addrow");
        return false;
    });

    /* Initialize the rule condition and action fields when displaying a rule */
    $('#section').on('show', '#modalRule', function(event) {
        if (event.target.id == 'modalRule') {
            $('#templates').find('option').removeAttr('id');
            $('#ruleConditions tr:not(.hidden) select[name$=attribute]').each(function() {
                updateCondition($(this));
            });
            $('#ruleActions tr:not(.hidden) select[name$=type]').each(function() {
                updateAction($(this), true);
            });
        }
    });

    /* Update a rule condition input field depending on the type of the selected attribute */
    function updateCondition(attribute) {
        var type = attribute.find(':selected').attr('data-type');
        var operator = attribute.next();

        if (type != operator.attr('data-type')) {
            // Disable fields to be replaced
            var value = operator.next();
            operator.attr('disabled', 1);
            value.attr('disabled', 1);

            // Replace operator field
            var operator_new = $('#' + type + '_operator').clone();
            operator_new.attr('id', operator.attr('id'));
            operator_new.attr('name', operator.attr('name'));
            operator_new.insertBefore(operator);

            // Replace value field
            var value_new = $('#' + type + '_value').clone();
            value_new.attr('id', value.attr('id'));
            value_new.attr('name', value.attr('name'));
            value_new.insertBefore(value);

            if (!operator.attr('data-type')) {
                // Preserve values of an existing condition
                operator_new.val(operator.val());
                value_new.val(value.val());
            }

            // Remove previous fields
            value.remove();
            operator.remove();

            // Remember the data type
            operator_new.attr('data-type', type);

            // Initialize rendering widgets
            initWidgets(value_new);
        }
    }

    /* Update the rule condition fields when adding a new condition */
    $('#section').on('admin.added', '#ruleConditions tr', function(event) {
        var attribute = $(this).find('select[name$=attribute]').first();
        updateCondition(attribute);
    });

    /* Update the rule condition fields when changing a condition attribute */
    $('#section').on('change', '#ruleConditions select[name$=attribute]', function(event) {
        updateCondition($(this));
    });

    /* Update the rule action fields when changing an action type */
    $('#section').on('change', '#ruleActions select[name$=type]', function(event) {
        updateAction($(this));
    });

    /* Update the rule action fields when adding a new action */
    $('#section').on('admin.added', '#ruleActions tr:not(.hidden)', function(event) {
        var type = $(this).find('select[name$=type]').first();
        updateAction(type);
    });

});
