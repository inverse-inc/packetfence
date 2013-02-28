function init() {

    $('#section').on('click','.disabled',function (event) {return false;})

    $('#section').on('click','[data-href-background]', function() {
        var that = $(this);
        var href = that.attr('data-href-background');
        var section = $('#section');
        var loader = section.prev('.loader');
        if (loader) loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(href)
        .always(function(){
            if (loader) loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
        })
        .done(function(data) {
            $(window).hashchange();
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError($("#section h2"), status_msg);
        });
        return false;
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/service/'));

    $(window).hashchange();
}
