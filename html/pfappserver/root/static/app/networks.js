var enforcementTypes = {
    'inline': ['inline'],
    'vlan': ['vlan-registration', 'vlan-isolation']
};

function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        var href = $(this).attr('href');
        saveStep(true, function(data) { window.location.href = href; } );
        return false; // don't follow link
    });
}

function initModals() {
    /* Interface modal editor */
    $('#modalEditInterface button[type="submit"]').click(function(event) {
        var modal = $('#modalEditInterface');
        var valid = true;
        modal.find('.control-group').each(function(index) {
            var e = $(this);
            if (e.find('input').first().val().trim().length == 0) {
                e.addClass('error');
                valid = false;
            }
            else
                e.removeClass('error');
        });
        if (valid) { 
            var ip = modal.find('#interfaceIp').val();
            var netmask = modal.find('#interfaceNetmask').val();
            var url = ['/interface',
                       modal.attr('interface'),
                       'edit',
                       ip,
                       netmask];
            var modal_body = modal.find('.modal-body').first();
            resetAlert(modal_body);
            $.ajax(url.join('/'))
                .done(function(data) {
                    modal.modal('toggle');
                    showSuccess($('#interfaces table'), data.status_msg);
                    refreshInterfaces();
                })
                .fail(function(jqXHR) {
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError(modal_body.children('form').first(), obj.status_msg);
                });
        }

        return false;
    });

    /* VLAN modal creator */
    $('#modalCreateVlan button[type="submit"]').click(function(event) {
        var modal = $('#modalCreateVlan');
        var valid = true;
        modal.find('.control-group').each(function(index) {
            var e = $(this);
            if (e.find('input').first().val().trim().length == 0) {
                e.addClass('error');
                valid = false;
            }
            else
                e.removeClass('error');
        });

        if (valid) {
            var name = modal.find('h3:first span').text() + '.' + modal.find('#vlanId').val(),
            modal_body = modal.children('.modal-body').first(),
            form = modal_body.children('form').first();
            if (form.attr('action') != '#created') {
                // Create VLAN
                var url = ['/interface',
                           'create',
                           name];
                resetAlert(modal_body);
                $.ajax(url.join('/'))
                    .done(function(data) {
                        form.attr('action', '#created');
                        editVlan(name, modal, form);
                    })
                    .fail(function(jqXHR) {
                        var obj = $.parseJSON(jqXHR.responseText);
                        alert(obj.status_msg);
                        showError(modal_body.children('form').first(), obj.status_msg);
                    });
            }
            else {
                // VLAN is already created
                editVlan(name, modal, form);
            }
        }

        return false;
    });
}

function editVlan(name, modal, form) {
    // Save attributes
    var url = ['/interface',
               name,
               'edit',
               modal.find('#vlanIp').val(),
               modal.find('#vlanNetmask').val()];
    $.ajax(url.join('/'))
        .done(function(data) {
            modal.modal('toggle');
            showSuccess($('#interfaces table'), data.status_msg);
            form.attr('action', '');
            refreshInterfaces();
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError(form, obj.status_msg);
            // Don't afraid the user, ignore next possible error
            refreshInterfaces(true);
        });
}

function initStep() {
    /* Enable/Disable toggle button */
    $('#interfaces tbody').on('click:toggled', '.btn-toggle', function(event) {
        var name = $(this).attr('interface');
        var action = $(this).attr('href').substr(1);
        var url = ['/interface', name, action];
        var row = $(this).closest('tr');
        var sibling = $('#interfaces table');
        $.ajax(url.join('/'))
            .done(function(data) {
                showSuccess(sibling, data.status_msg);
            })
            .fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError(sibling, obj.status_msg);
            });
    });

    /* Edit button */
    $('#interfaces tbody').on('click', '[href=#modalEditInterface]', function(event) {
        var modal = $('#modalEditInterface');
        var row = $(this).closest('tr');
        var cells = row.children('td');
        modal.attr('interface', $(this).attr('interface'));
        modal.find('h3:first span').html($(cells[0]).html());
        modal.find('#interfaceIp').val($(cells[1]).text());
        modal.find('#interfaceNetmask').val($(cells[2]).text());
        // Silently save current step before displaying modal
        saveStep(false);
    });

    /* Create VLAN button */
    $('#interfaces tbody').on('click', '[href=#modalCreateVlan]', function(event) {
        var modal = $('#modalCreateVlan');
        var cells = $(this).closest('tr').children('td');
        modal.find('h3:first span').html($(cells[0]).html());
        modal.find('input').val('');
        // Silently save current step before displaying modal
        saveStep(false);
    });

    /* Delete VLAN button */
    $('#interfaces tbody').on('click', '[href=#deleteVlan]', function(event) {
        var row = $(this).closest('tr');
        var url = ['/interface',
                   $(this).attr('interface'),
                   'delete'];
        $.ajax(url.join('/'))
            .done(function(data) {
                showSuccess($('#interfaces table'), data.status_msg);
                row.fadeOut('slow', function() { $(this).remove(); });
            })
            .fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#interfaces table'), obj.status_msg);
            });        
    });

    /* Management interface must be unique */
    $('#interfaces tbody').on('change', 'select[name="type"]', function(event) {
        var disable = false;
        $('select[name="type"] option[value="management"]').each(function(index) {
            if (this.selected)
                disable = true;
            return !disable;
        });
        $('select[name="type"] option[value="management"]').each(function(index) {
            if (!this.selected)
                this.disabled = disable;
        });
    });
    $('select[name="type"]:first').trigger('change');
}

function refreshInterfaces(noAlert) {
    $.ajax('/interface/all/get')
        .done(function(data) {
            var table = $('#interfaces tbody');
            table.html(data);
            $('select[name="type"]:first').trigger('change');
        })
        .fail(function(jqXHR) {
            if (!noAlert) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#interfaces table'), obj.status_msg);
            }
        });
}

function saveStep(validate, successCallback) {
    var valid = true;
    if (validate) {
       $('#interfaces .control-group').each(function(index) {
            var control = $(this);
            var input = control.find('input:text').first();
            if (input.length) {
                if (input.val().trim().length == 0) {
                    control.addClass('error');
                    valid = false;
                }
                else
                    control.removeClass('error');
            }
        });
    }
    if (valid) {
        var data = {
            interfaces_types: {},
            gateway: $('#gateway').val(),
            dns: $('#dns').val()
        };
        $('#interfaces select[name="type"]').each(function(index) {
            data.interfaces_types[$(this).attr('interface')] = $(this).val();
        });
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: {json: $.toJSON(data)}
        }).done(function(data) {
            if (typeof successCallback == 'function') successCallback(data);
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            if (validate) {
                showError($('#interfaces form'), obj.status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            }
        });
    }
    else {
        resetAlert($('#interfaces'));
        showError($('form[name="interfaces"]'), 'Please verify your configuration.');
        $("body,html").animate({scrollTop:0}, 'fast');
    }
}