var disableToggle = false;

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
                        // Stop the hidden event bubbling up to the modal
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

    /* Handle dynamic loading of violations */
    $('body').on('show', '#modalNode [data-toggle="tab"][data-target][href]', function(event) {
        var that = $(this);
        var target = $(that.attr("data-target"));
        if (target.children().length == 0)
            target.load(that.attr("href"), function() {
                target.find('.switch').bootstrapSwitch();
            });
        return true;
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

    /* Trigger a violation (from the modal editor) */
    $('body').on('click', '#addViolation', function(event) {
        var btn = $(this),
        modal = $('#modalNode'),
        modal_body = modal.find('.modal-body'),
        sibbling = modal_body.children().first(),
        href = btn.attr('href'),
        vid = modal.find('#vid').val();
        resetAlert(modal_body);
        $.ajax([href, vid].join('/'))
            .done(function(data) {
                //showSuccess(sibbling, data.status_msg);
                var content = $('#nodeViolations');
                content.html(data);
                content.find('.switch').bootstrapSwitch();
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                btn.button('reset');
                showPermanentError(sibbling, status_msg);
            });

        return false;
    });

    /* Open/close a violation */
    $('body').on('switch-change', '#nodeViolations .switch', function(e) {
        e.preventDefault();

        // Ignore event if it occurs while processing a toggling
        if (disableToggle) return;
        disableToggle = true;

        var btn = $(e.target);
        var name = btn.find('input:checkbox').attr('name');
        var status = btn.bootstrapSwitch('status');
        var action = status? "open" : "close";
        var pane = $('#nodeViolations');
        resetAlert(pane.parent());
        var url = ['/node',
                   action,
                   name.substr(10)]; // remove "violation." prefix
        $.ajax(url.join('/'))
            .done(function(data) {
                showSuccess(pane, data.status_msg);
                disableToggle = false;
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError(pane, status_msg);
                // Restore switch state
                btn.bootstrapSwitch('setState', !status, true);
                disableToggle = false;
            });
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));

    $(window).hashchange();
}
