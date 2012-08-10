function init() {
    /* Register graph links in the sidebar list */
    $('.sidebar-nav .nav-list a').click(function(event) {
        var href = $(this).attr('href');
        var graph = $('#section .graph');
        var loader = $('#section .loader');
        var item = $(this).parent();
        $('.sidebar-nav .nav-list .active').removeClass('active');
        item.addClass('active');
        $('#section .graph').fadeOut('fast', function() {
            $(this).empty();
            graphs = {};
            loader.show();
            $.ajax(href)
                .done(function(data) {
                    loader.hide();
                    graph.html(data);
                    graph.show();
                    graph.find('.counter [rel="tooltip"]').tooltip({ placement: 'left' });
                    graph.find('.options [rel="tooltip"]').tooltip({ placement: 'right' });
                    drawGraphs();
                })
                .fail(function(jqXHR) {
                    if (jqXHR.status == 401) {
                        // Unauthorized; redirect to URL specified in the location header
                        window.location.href = jqXHR.getResponseHeader('Location');
                    }
                    else {
                        loader.hide();
                        var obj = $.parseJSON(jqXHR.responseText);
                        showError(graph, obj.status_msg);
                    }
                });
        });

        return false;
    });

    /* Register graph options links */
    $('#section').on('click', '.options a[class!="favorite"]', function(event) {
        graphs = {};
        var graph = $('#section .graph');
        graph.fadeTo('fast', 0.5);
        $.ajax($(this).attr('href'))
            .done(function(data) {
                graph.html(data);
                graph.fadeTo('fast', 1.0);
                graph.find('.counter [rel="tooltip"]').tooltip({ placement: 'left' });
                graph.find('.options [rel="tooltip"]').tooltip({ placement: 'right' });
                drawGraphs();
            })
            .fail(function(jqXHR) {
                if (jqXHR.status == 401) {
                    // Unauthorized; redirect to URL specified in the location header
                    window.location.href = jqXHR.getResponseHeader('Location');
                }
                else {
                    var obj = $.parseJSON(jqXHR.responseText);
                    showError(graph, obj.status_msg);
                    graph.fadeTo('fast', 1.0);
                }
            });

        return false;
    });

    /* Register the favorite (add/remove from dashboard) link */
    $('#section').on('click', '.favorite', function(event) {
        var icon = $(this).children('i');
        var action = "add";
        icon.tooltip('hide');
        icon.toggleClass('icon-star-empty');
        icon.toggleClass('icon-star');
        if (icon.hasClass('icon-star-empty')) action = "remove";
        var graph_id = $(this).parentsUntil('.report').nextAll('.chart').attr('id');
        console.info("Toggling " + graph_id + " as favorite");
        var url = [$(this).attr('href'), graph_id, action];
        // Send the action (add or remove)
        $.ajax(url.join('/'))
        .done(function(data) {
                
        })
        .fail(function(jqXHR) {
            if (jqXHR.status == 401) {
                // Unauthorized; redirect to URL specified in the location header
                window.location.href = jqXHR.getResponseHeader('Location');
            }
            else {
                var obj = $.parseJSON(jqXHR.responseText);
                showError($('#section .graph'), obj.status_msg);
            }
        });

        return false;
    });

    /* Load initial graph */
    $('.sidebar-nav .nav-list a').first().trigger('click');
}