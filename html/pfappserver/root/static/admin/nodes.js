function init() {
    $('.datepicker').datepicker({
        endDate: new Date(), // today
        autoclose: true
    });

    /* View a node (show the modal editor) */
    $('#section').on('click', '[href*="#modalNode"]', function(event) {
        var url = $(this).attr('href');
        var section = $('#section');
        var loader = section.prev('.loader');
        loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(url)
        .always(function() {
            loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        })
        .done(function(data) {
            $('body').append(data);
            $('#modalNode').modal({show: true});
            $('#modalNode').one('shown', function(event) {
                var modal = $(this);
                modal.find('.chzn-select').chosen();
                modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
                modal.find('.timepicker-default').each(function() {
                    // Keep the placeholder visible if the input has no value
                    var defaultTime = $(this).val().length? 'value' : false;
                    $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
                });
                modal.find('.datepicker').datepicker({ autoclose: true });
                modal.find('a[href="#nodeHistory"]').on('shown', function () {
                    if ($('#nodeHistory .chart').children().length == 0)
                        drawGraphs();
                });
                $('#modalNode').one('hidden', function (eventObject) {
                    // Destroy the modal unless the event is coming from
                    // an input field (See bootstrap-timepicker.js)
                    if (eventObject.target.tagName != 'INPUT') {
                        $(this).remove();
                    }
                });
            });
        })
        .fail(function(jqXHR) {
            var status_msg;
            try {
                var obj = $.parseJSON(jqXHR.responseText);
                status_msg = obj.status_msg;
            }
            catch(e) {}
            if (!status_msg) status_msg = _("Cannot Load Content");
            showPermanentError(section, status_msg);
        });

        return false;
    });

    /* Save a node (from the modal editor) */
    $('body').on('click', '#updateNode', function(event) {
        var btn = $(this),
        modal = $('#modalNode'),
        form = modal.find('form').first(),
        modal_body = modal.find('.modal-body'),
        url = btn.attr('href'),
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
                var status_msg;
                btn.button('reset');
                try {
                    var obj = $.parseJSON(jqXHR.responseText);
                    status_msg = obj.status_msg;
                }
                catch(e) {}
                if (!status_msg) status_msg = _("Cannot Load Content");
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });

    /* Delete a node (from the modal editor) */
    $('body').on('click', '#deleteNode', function(event) {
        var btn = $(this),
        modal = $('#modalNode'),
        modal_body = modal.find('.modal-body'),
        url = btn.attr('href');
        $.ajax(url)
            .done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            }).fail(function(jqXHR) {
                var status_msg;
                btn.button('reset');
                try {
                    var obj = $.parseJSON(jqXHR.responseText);
                    status_msg = obj.status_msg;
                }
                catch(e) {}
                if (!status_msg) status_msg = _("Cannot Load Content");
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });

        return false;
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));

    $(window).hashchange();
}
