function init() {

    function updateGraphSection(href) {
        var section = $('#section');
        var graph   = section.find('.graph');
        var loader  = section.prev('.loader');
        graph.fadeOut('fast', function() {
            $(this).empty();
            graphs = {};
            loader.show();
            $.ajax(href)
                .always(function() {
                    loader.hide();
                })
                .done(function(data) {
                    graph.html(data);
                    graph.show();
                    graph.find('.counter [rel="tooltip"]').tooltip({ placement: 'left' });
                    graph.find('.options [rel="tooltip"]').tooltip({ placement: 'right' });
                    drawGraphs();
                })
                .fail(function(jqXHR) {
                    var status_msg = getStatusMsg(jqXHR);
                    showError(graph, status_msg);
                });
        });

        return false;
    }

    /* Register graph options links */
    $('#section').on('click', '.options a[class!="favorite"]', function(event) {
        graphs = {};
        var graph = $('#section .graph');
        graph.fadeTo('fast', 0.5);
        $.ajax($(this).attr('href'))
            .always(function() {
                graph.fadeTo('fast', 1.0);
            })
            .done(function(data) {
                graph.html(data);
                graph.find('.counter [rel="tooltip"]').tooltip({ placement: 'left' });
                graph.find('.options [rel="tooltip"]').tooltip({ placement: 'right' });
                drawGraphs();
            })
            .fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showError(graph, status_msg);
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
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section .graph'), status_msg);
        });

        return false;
    });

    /* Hash change halder */
    $(window).hashchange(pfOnHashChange(updateGraphSection,'/graph/'));

    /* Load initial graph */
    $(window).hashchange();
    var link_query = '.sidebar-nav .nav-list .active a';
    var hash = location.hash.replace(/\/.*$/,'');
    if(hash && hash != '#') {
       link_query = '.sidebar-nav .nav-list a[href="' + hash + '"]';
    }

    $(link_query).trigger('click');
}
