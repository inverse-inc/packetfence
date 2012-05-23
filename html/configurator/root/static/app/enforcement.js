var enforcementTypes = {
    'inline': ['inline'],
    'vlan': ['registration', 'isolation']
};

function registerExists() {
    $('#tracker a, .form-actions a').click(function(event) {
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
            var ip = modal.find('#interfaceIp').val(),
            netmask = modal.find('#interfaceNetmask').val();
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
            var name = modal.find('h3:first span').text() + '.' + modal.find('#vlanId').val();
            var modal_body = modal.find('.modal-body').first();
            var form = modal_body.children('form').first();
            if (form.attr('action') != '#created') {
                var url = ['/interface',
                           'create',
                           name];
                resetAlert(modal_body);
                $.ajax(url.join('/'))
                    .done(function(data) {
                        // Creation succeed
                        form.attr('action', '#created');
                        refreshInterfaces();
                    })
                    .fail(function(jqXHR) {
                        var obj = $.parseJSON(jqXHR.responseText);
                        showError(modal_body.children('form').first(), obj.status_msg);
                        valid = false;
                    });
            }
            if (valid) {
                // Save attributes
                url = ['/interface',
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
                        showError(modal_body.children('form').first(), obj.status_msg);
                    });
            }
        }
    });
}

function initStep() {
    /* Enforcement mechanisms checkboxes */
    $('input:checkbox[name$="enforcement"]').change(function(event) {
        var disable = !this.checked;
        var type = $(this).val();
        $('select[name="type"] option').each(function(index) {
            for (var i = 0; i < enforcementTypes[type].length; i++) {
                var t = enforcementTypes[type][i];
                if (t == $(this).val())
                    this.disabled = disable;
            }
        });
    }).trigger('change');

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
    });

    /* Create VLAN button */
    $('#interfaces tbody').on('click', '[href=#modalCreateVlan]', function(event) {
        var modal = $('#modalCreateVlan');
        var cells = $(this).closest('tr').children('td');
        modal.find('h3:first span').html($(cells[0]).html());
        modal.find('input').val('');
    });

    /* Delete VLAN button */
    $('#interfaces tbody').on('click', '[href=#modalDeleteVlan]', function(event) {
        var row = $(this).closest('tr');
        var url = ['/interface',
                   $(this).attr('interface'),
                   'delete'];
        $.ajax(url.join('/'))
            .done(function(data) {
                showSuccess($('#interfaces table'), data.status_msg);
                row.fadeOut('slow');
            })
            .fail(function(jqXHR) {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#interfaces table'), obj.status_msg);
            });        
    });

    /* Management interface must be unique */
    $('select[name="type"]').change(function(event) {
        var disable = false;
        $('select[name="type"] option[value="management"]').each(function(index) {
            if (this.selected) {
                disable = true;
                return false;
            }
        });
        $('select[name="type"] option[value="management"]').each(function(index) {
            if (!this.selected) this.disabled = disable;
        });
    }).first().trigger('change');
}

function refreshInterfaces() {
    saveStep(false);
    $.ajax('/interface/all/get')
        .done(function(data) {
            var table = $('#interfaces tbody');
            table.html(data);
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#interfaces table'), obj.status_msg);
        });
}

function saveStep(validate, successCallback) {
    var valid = true;
    if (validate) {
        $('#interfaces .control-group').each(function(index) {
            var e = $(this);
            var i = e.find('input:text').first();
            if (i.length) {
                if (i.val().trim().length == 0) {
                    e.addClass('error');
                    valid = false;
                }
                else
                    e.removeClass('error');
            }
            var i = e.find('input:checkbox');
            if (i.length) {
                if (i.filter(':checked').length == 0) {
                    e.addClass('error');
                    valid = false;
                }
                else
                    e.removeClass('error');
            }
        });
    }
    if (valid) {
        var form = {
            enforcements: [],
            types: {},
            gateway: $('#gateway').val()
        };
        $('input:checkbox:checked[name="enforcement"]').each(function(index) {
            form.enforcements.push($(this).val());
        });
        $('#interfaces select[name="type"]').each(function(index) {
            form.types[$(this).attr('interface')] = $(this).val();
        });
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: {json: $.toJSON(form)}
        }).done(function(data) {
            if (typeof successCallback == 'function') successCallback(data);
        }).fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#interfaces form'), obj.status_msg);
            $("body").animate({scrollTop:0}, 'fast');
        });
    }
    else {
        showError($('form'), 'Please verify your configuration.');
        $("body").animate({scrollTop:0}, 'fast');
    }
}