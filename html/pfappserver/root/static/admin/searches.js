function saveSearchFromForm(form_id) {
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
                location.reload();
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });
        return false;
    });
    modal.modal('show');
    modal.on('shown', function(event) {
        $(this).find(':input:first').focus();
    });
    return true;
}

$(function() {
    $('#advancedSavedSearchBtn').on('click', function(event) {
        return saveSearchFromForm("#advancedSearch");
    });

    $('#simpleSavedSearchBtn').on('click', function(event) {
        return saveSearchFromForm('#simpleSearch');
    });

    /* For simpleSearch */
    $('body').on('submit','#simpleSearch', function(event) {
        var form = $(this);
        var section = $('#section');
        section.fadeTo('fast', 0.5);
        var url = form.attr('action');
        var inputs = form.serializeArray();
        var length = inputs.length;
        if(length > 0) {
            for(var i =0;i<length;i++) {
                var input = inputs[i];
                if(input.value) {
                    url+= "/" + encodeURIComponent(input.name)   + "/" + encodeURIComponent(input.value);
                }
            }
        }
        updateSection(url);
        return false;
    });

    $('#advancedSearch').on('submit',function(event) {
        updateSectionFromForm($('#advancedSearch'));
        return false;
    });

    $('#advancedSearch').on('admin.added','tr', function(event) {
        var that = $(this);
        that.find(':input').removeAttr('disabled');
    });

    $('body').on('click','[data-toggle="pf-search-form][data-target]"',function(event) {
        var that = $(this);
        var target = that.attr('data-target');
        var from_form = that.next();
        var to_form   = $("#" +target +"Search"  );
        var first_row = to_form.find('tbody tr.dynamic-row:not(.hidden)').first();
        first_row.nextAll("tr.dynamic-row:not(.hidden)").remove();
        var new_searches =  from_form.find('[name^="searches."]').length / 3 - 1;
        for(var i=0;i<new_searches;i++) {
            first_row.find('[href="#add"]').click();
        }
        from_form.find(':input').each(function(e){
            to_form.find('[name="' + this.name + '"]:not(:disabled)').val(this.value);
        });
        $('[data-toggle="tab"][href="#' + target  + '"]').tab('show');
        to_form.submit();
    });


    $('.saved_search_trash').on('click',function(event) {
        event.stopPropagation();
        var that = $(this);
        $.ajax(that.attr('data-href'))
            .always(function() {})
            .done(function(data) {
                that.closest('li').remove();
            })
            .fail(function(jqXHR) {
                $("body,html").animate({scrollTop:0}, 'fast');
                var status_msg = getStatusMsg(jqXHR);
                showError($('#section h2'), status_msg);
            });

    });
});
