$(function() { // DOM ready
});

function init() {
    $('#section').on('section.loaded', function(event) {
        $('[id$="Empty"]').on('click', '[href="#add"]', function(event) {
            var match = /(.+)Empty/.exec(event.delegateTarget.id);
            var id = match[1];
            var emptyId = match[0];
            $('#'+id).trigger('addrow');
            $('#'+emptyId).addClass('hidden');
            return false;
        });
        var modal  = $("#savedSearch");
        modal.on('shown', function(event) {
            $(this).find(':input:first').focus();
        });
        var saved_search_form = $("#savedSearchForm");
        var search_form = $('#search');
        saved_search_form.on('submit', function(event) {
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
        modal.on('shown', function(event) {
            $(this).find(':input:first').focus();
        });
    });
    /* Initialize datepickers */
    $(window).hashchange(pfOnHashChange(updateSection,'/dhcpoption82/'));
    $(window).hashchange();
}
