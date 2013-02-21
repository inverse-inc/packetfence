function init() {
    $('.datepicker').datepicker({
        endDate: new Date(), // today
        autoclose: true
    });

    /* Sort the search results */
    $('#section').on('click', 'thead a', function(event) {
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
            section.html(data);
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError(section, status_msg);
        });

        return false;
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
            var modalNode = $("#modalNode");
            modalNode.one('shown', function(event) {
                var modal = $(this);
                modal.find('.chzn-select').chosen();
                modal.find('.chzn-deselect').chosen({allow_single_deselect: true});
                modal.find('.timepicker-default').each(function() {
                    // Keep the placeholder visible if the input has no value
                    var that = $(this);
                    var defaultTime = that.val().length? 'value' : false;
                    that.timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
                    that.on('hidden',function (e){
                        //Stop the hidden event bubbling up to the modal
                        e.stopPropagation();
                    });
                });
                modal.find('.datepicker').datepicker({ autoclose: true });
                modal.find('a[href="#nodeHistory"]').on('shown', function () {
                    if ($('#nodeHistory .chart').children().length == 0)
                        drawGraphs();
                });
            });
            modalNode.on('hidden', function (eventObject) {
                $(this).remove();
            });
            modalNode.modal({show: true});
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
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
                btn.button('reset');
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
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
                var status_msg = getStatusMsg(jqXHR);
                btn.button('reset');
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });

        return false;
    });

    $('#nodeAdvancedSearchBtn').on('click',function(event) {
        updateSectionFromForm($('#nodeAdvancedSearch'));
        return false;
    });

    $('#nodeAdvancedSearch').on('admin.added','tr', function(event) {
        var that = $(this);
        that.find(':input').removeAttr('disabled');
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));

    $(window).hashchange();
}
