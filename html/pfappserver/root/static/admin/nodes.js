function SaveSearchFromForm(form_id) {
    var modal  = $("#savedSearch");
    var button = modal.find('a.btn-primary').first();
    var saved_search_form = $("#savedSearchForm");
    var search_form = $(form_id);
    button.off('click');
    button.on('click',function(event) {
        modal.modal('hide');
        var uri = new URI(search_form.attr('action'));
        var query = uri.resource()
            + "?"
            + search_form.serialize();
        query = query.replace(/^\//,'');
        saved_search_form
        .find('[name="query"]')
        .attr('value',query);
        $.ajax({
            'url'  : saved_search_form.attr('action'),
            'type' : saved_search_form.attr('method') || "POST",
            'data' : saved_search_form.serialize()
            })
            .always(function() {
                modal.modal('hide');
                saved_search_form[0].reset();
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
    modal.modal('show');
    return true;
}
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

    $('#nodeAdvancedSavedSearchBtn').on('click', function(event) {
        return SaveSearchFromForm("#nodeAdvancedSearch");
    });

    $('#nodeSimpleSavedSearchBtn').on('click', function(event) {
        return SaveSearchFromForm('#simpleSearch');
    });


    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));

    $(window).hashchange();
}
