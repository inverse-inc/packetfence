function init() {
    $('.datepicker').datepicker({
        endDate: new Date() // today
    });

    /* Search */
    $('form[name="simpleSearch"]').submit(function(event) {
        var form = $(this);
        var results = $('#results');
        results.fadeTo('fast', 0.5);
        $.ajax({
            type: 'POST',
            url: form.attr('action'),
            data: { filter: $('#simpleString').val() }
        }).done(function(data) {
            results.html(data);
            results.stop();
            results.fadeTo('fast', 1.0);
        }).fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                var obj = $.parseJSON(jqXHR.responseText);
                showPermanentError($('#results'), obj.status_msg);
            }
        });
        
        return false;
    });

    /* Node editor */
    $('#results').on('click', '[href*="#modalNode"]', function(event) {
        var mac = this.innerHTML;
        var url = ['/node', mac, 'get'];
        $.ajax(url.join('/'))
        .done(function(data) {
            $('body').append(data);
            $('#modalNode').modal({show: true});
            $('#modalNode a[href="#nodeHistory"]').on('shown', function () {
                if ($('#nodeHistory .chart').children().length == 0)
                    drawGraphs();
            });
            $('#modalNode').on('hidden', function () {
                $(this).remove();
            });
        })
        .fail(function(jqXHR) {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#results'), obj.status_msg);
        });
    });

    /* Initial search */
    $.ajax('/node/search')
    .done(function(data) {
        var results = $('#results');
        results.html(data);
    })
    .fail(function(jqXHR) {
        if (jqXHR.status == 401) {
            // Unauthorized; redirect to URL specified in the location header
            window.location.href = jqXHR.getResponseHeader('Location');
        }
        else {
            var obj = $.parseJSON(jqXHR.responseText);
            showError($('#results'), obj.status_msg);
        }
    });
}
