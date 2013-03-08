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

$(function() {
    $('#advancedSavedSearchBtn').on('click', function(event) {
        return saveSearchFromForm("#advancedSearch");
    });

    $('#simpleSavedSearchBtn').on('click', function(event) {
        return saveSearchFromForm('#simpleSearch');
    });

    $('#advancedSearchBtn').on('click',function(event) {
        updateSectionFromForm($('#advancedSearch'));
        return false;
    });

    $('#advancedSearch').on('admin.added','tr', function(event) {
        var that = $(this);
        that.find(':input').removeAttr('disabled');
    });
});
