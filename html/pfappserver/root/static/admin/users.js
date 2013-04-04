
function init() {

    /* View a user (show the modal editor) */
    $('#section').on('click', '[href*="#modalUser"]', function(event) {
        var modal = $('#modalUser');
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
                modal.modal({ shown: true });
                modal.on('shown', function() {
                    $('#pid').focus();
                });
                modal.find('.datepicker').datepicker({ autoclose: true });
                modal.find('#ruleActions tr:not(.hidden) select[name$=type]').each(function() {
                    updateAction($(this),true);
                });
            })
            .fail(function(jqXHR) {
                modal.modal('hide');
                $("body,html").animate({scrollTop:0}, 'fast');
                if (jqXHR.status == 404) {
                    $(window).hashchange();
                }
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

        return false;
    });

    /* Save a user (from the modal editor) */
    $('body').on('click', '#updateUser', function(event) {
        var btn = $(this),
        modal = $('#modalUser'),
        form = modal.find('form').first(),
        modal_body = modal.find('.modal-body'),
        url = $(this).attr('href'),
        valid = false;
        valid = isFormValid(form);
        if (valid) {
            btn.button('loading');
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
                var status_msg = getStatusMsg(jqXHR);
                btn.button('reset');
                resetAlert(modal_body);
                showPermanentError(modal_body.children().first(), status_msg);
            });
        }

        return false;
    });


    /* Delete a user (from the modal editor) */
    $('body').on('click', '#deleteUser', function(event) {
        var modal = $('#modalUser');
        var url = $(this).attr('href');
        $.ajax(url)
            .done(function(data) {
                modal.modal('hide');
                modal.on('hidden', function() {
                    $(window).hashchange();
                });
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
                $("body,html").animate({scrollTop:0}, 'fast');
            });

        return false;
    });

    $("#modalUser").on('show','[data-toggle="tab"][data-target][href]',function(event) {
        var that = $(this);
        var target = $(that.attr("data-target"));
        target.load(that.attr("href"));
        return true;
    });
    /* View a node (show the modal editor) */
    $('body').on('click', '[href*="#modalNode"]', function(event) {
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
            var modalUser = $("#modalUser");
            modalUser.one('hidden',function(event){
                modalNode.modal('show');
            });
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
            modalNode.one('hidden', function (eventObject) {
                $(this).remove();
                modalUser.modal('show');
            });

            modalUser.modal('hide');
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError(section, status_msg);
        });
        return false;
    });
        /* Initialize the action field */
    /* Update the rule action fields when changing an action type */
    $('#modalUser').on('change', '#ruleActions select[name$=type]', function(event) {
        updateAction($(this));
    });

    $('#modalUser').on('admin.added','tr', function(event) {
        var that = $(this);
        that.find(':input').removeAttr('disabled');
        var type = that.find('select[name$=type]').first();
        updateAction(type);
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/user'));

    $(window).hashchange();
}

