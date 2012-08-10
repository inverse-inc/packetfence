function init() {
    $('.datepicker').datepicker({
        endDate: new Date() // today
    });

    /* Search */
    $('form[name="simpleSearch"]').submit(function(event) {
        var form = $(this);
        var results = $('#results');
        results.fadeTo('fast', 0.5);
        $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: { filter: $('#simpleString').val() }
        }).done(function(data) {
            results.html(data);
            results.stop();
            results.fadeTo('fast', 1.0);
        }).fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                var obj = $.parseJSON(jqXHR.responseText);
                showPermanentError($('#results'), obj.status_msg);
            }
        });
        
        return false;
    });

    /* Node editor */
    $('#results').on('click', '[href*="#modalNode"]', function(event) {
        var mac = this.innerHTML;
        var url = ['/node', mac, 'get'];
        $.ajax(url.join('/'))
        .done(function(data) {
            $('body').append(data);
            $('#modalNode').modal({show: true});
            $('#modalNode .chzn-select').chosen();
            $('#modalNode .chzn-deselect').chosen({allow_single_deselect: true});
            $('#modalNode .timepicker-default').each(function() {
                // Keep the placeholder visible if the input has no value
                var defaultTime = $(this).val().length? 'value' : false;
                $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
            });
            $('#modalNode .datepicker').datepicker();
            $('#modalNode a[href="#nodeHistory"]').on('shown', function () {
                if ($('#nodeHistory .chart').children().length == 0)
                    drawGraphs();
            });
            $('#modalNode').on('hidden', function (eventObject) {
                // Destroy the modal unless the event is coming from
                // an input field (See bootstrap-timepicker.js)
                if (eventObject.target.tagName != 'INPUT') {
                    $(this).remove();
                    // Remove the 'pickers' appended to the body
                    $('.datepicker').remove();
                    $('.bootstrap-timepicker').remove();
                }
            });
        })
        .fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#results'), obj.status_msg);
            }
        });
    });
    $('body').on('click', '#editNode', function(event) {
        var btn = $(this),
        modal = $('#modalNode'),
        form = modal.find('form').first(),
        modal_body = modal.find('.modal-body'),
        url = form.attr('action');

        btn.button('loading');
        $.ajax({
            type: 'POST',
            url: url,
            data: { category_id: form.find('[name="category_id"]').val(),
                    status: form.find('[name="status"]').val(),
                    reg_date: form.find('[name="reg_date"]').val(),
                    reg_time: form.find('[name="reg_time"]').val(),
                    unreg_date: form.find('[name="unreg_date"]').val(),
                    unreg_time: form.find('[name="unreg_time"]').val() }
        }).done(function(data) {
            modal.modal('hide');
        }).fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                btn.button('reset');
                var obj = $.parseJSON(jqXHR.responseText);
                resetAlert(modal_body);
                showError(modal_body.children().first(), obj.status_msg);
            }
        });

        return false;
    });
    $('body').on('click', '#deleteNode', function(event) {
        alert("delete node");
        return false;
    });

    /* Initial search */
    $.ajax('/node/search')
    .done(function(data) {
        var results = $('#results');
        results.html(data);
    })
    .fail(function(jqXHR) {
        if (jqXHR.status == 401) {
            // Unauthorized; redirect to URL specified in the location header
            window.location.href = jqXHR.getResponseHeader('Location');
        }
        else {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#results'), obj.status_msg);
        }
    });
}
