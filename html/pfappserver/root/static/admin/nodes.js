function init() {
    $('.datepicker').datepicker({
        endDate: new Date() // today
    });

    /* Sort the search results */
    $('#section').on('click', 'thead a', function(event) {
        var url = $(this).attr('href');
        var section = $('#section');
        section.fadeTo('fast', 0.5);
        $.ajax(url)
        .always(function() {
            section.stop();
            section.fadeTo('fast', 1.0);
        })
        .done(function(data) {
            section.html(data);
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showPermanentError(section, obj.status_msg);
        });

        return false;
    });

    /* View a node (show the modal editor) */
    $('#section').on('click', '[href*="#modalNode"]', function(event) {
        var url = $(this).attr('href');
        $.ajax(url)
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
                }
            });
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#section'), obj.status_msg);
        });

        return false;
    });

    /* Save a node (from the modal editor) */
    $('body').on('click', '#updateNode', function(event) {
        var btn = $(this),
        modal = $('#modalNode'),
        form = modal.find('form').first(),
        modal_body = modal.find('.modal-body'),
        url = $(this).attr('href'),
        valid = false;
        btn.button('loading');
        valid = isFormValid(form);
        if (valid) {
            $.ajax({
                type: 'POST',
                url: url,
                data: form.serialize()
            }).done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            }).fail(function(jqXHR) {
                btn.button('reset');
                var obj = $.parseJSON(jqXHR.responseText);
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), obj.status_msg);
            });
        }

        return false;
    });

    /* Delete a node (from the modal editor) */
    $('body').on('click', '#deleteNode', function(event) {
        alert("delete node");
        return false;
    });

    $(window).hashchange(pfOnHashChange('/node/',updateSection));

    $(window).hashchange();
}
