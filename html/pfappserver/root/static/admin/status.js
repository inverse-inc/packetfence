var refresh = {
    timeout: null,
    callback: function() { $(window).hashchange(); },
    delay: 60000 // in miliseconds
};

function updateGraphSection(graph) {
    var dp = $('.datepicker').data('datepicker');
    var start = dp.dates[0];
    var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
    var end = dp.dates[1];
    var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
    if (!graph) {
        var section = $('#section');
        var name = section.find('.nav .active a').attr('href');
        var tab = $(name.substr(name.indexOf('#')));
        if (tab.length) {
            graph = tab.find('.graph:first');
        }
        else {
            return;
        }
    }
    var url = [graph.attr('data-uri'), startDate, endDate];
    var href = url.join('/');
    $.ajax(href)
        .done(function(data) {
            graph.html(data);
            var id = graph.find('.chart').attr('id');
            if (id)
                drawGraphs(id);
        })
        .fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(graph, status_msg);
        });

    return false;
}

function init() {

    /* Reload dashboard when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).closest('.datepicker').data('datepicker');
        var start = dp.dates[0];
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var end = dp.dates[1];
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        location.hash = ['graph', 'dashboard', startDate, endDate].join('/');
    });

    /* Automatically refresh dashboard every X seconds */
    $('#section').on('section.loaded', function(event) {
        var section = $(this);
        if (section.children('#dashboard').length) {
            updateGraphSection();

            // Set the end date of the range datepickers to today
            var today = new Date();
            $('.datepicker').find('input').each(function() { $(this).data('datepicker').setEndDate(today) });

            if (refresh.timeout)
                window.clearTimeout(refresh.timeout);
            refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
        }
        else {
            window.clearTimeout(refresh.timeout);
        }
    });

    /* Build graph when changing tab on the dashboard */
    $('#section').on('shown', 'a[data-toggle="tab"]', function(event) {
        var name = $(event.target).attr('href');
        var tab = $(name.substr(name.indexOf('#')));
        var graph = tab.find('.graph:first');
        updateGraphSection(graph)
    });

    function retryStatusPage(attempt) {
        if(attempt) {
            var section = $('#section');
            var loader = section.prev('.loader');
            if (loader) loader.show();
            section.fadeTo('fast', 0.5);
            $.ajax("/service/status")
                .always(function() {
                    if (loader) loader.hide();
                    section.stop();
                    section.fadeTo('fast', 1.0);
                })
                .done(function(data, textStatus, jqXHR) {
                    section.find('.datepicker').datepicker({ autoclose: true });
                    if (section.chosen) {
                        section.find('.chzn-select').chosen();
                        section.find('.chzn-deselect').chosen({allow_single_deselect: true});
                    }
                    if (section.bootstrapSwitch)
                        section.find('.switch').bootstrapSwitch();
                    section.trigger('section.loaded');
                    section.html(data);
                })
                .fail(function(jqXHR) {
                    delayedRefresh(--attempt);
                });
        } else {
            showPermanentError($("#section .table"), "Maximum attempts reached");
        }
    }

    function delayedRefresh(attempt) {
        var timeout = 60;
        var section_table = $("#section .table");
        showAlert("#deferred_service_alert", section_table, timeout.toString(), true);
        var alert_section = section_table.prev('.alert');
        var timerId = setInterval(
            function() {
                if(timeout > 0) {
                    timeout--;
                    alert_section.find('span').first().html(timeout.toString());
                }
            }
            ,1000
        );
        var doRefresh = function() {
            clearInterval(timerId);
            alert_section.remove();
            retryStatusPage(attempt);
        };
        var refreshTimeoutId = setTimeout(
            function() {
                alert_section.find('.btn').off('click.refresh');
                doRefresh();
            },
            timeout * 1000
        );
        alert_section.find('.btn').on('click.refresh',function() {
                clearTimeout(refreshTimeoutId);
                doRefresh();
            }
        );
    }

    $("#section").on('click.modal.data-api', '[data-toggle="modal"][data-target][data-confirm-stop-href]', function (e) {
        var that = $(this);
        var href = that.attr("data-confirm-stop-href");
        var modal = $(that.attr("data-target"));
        modal.find(".btn-primary").first().on('click',function(e){
            var section = $('#section');
            var loader = section.prev('.loader');
            if (loader) loader.show();
            $.ajax(href)
                .always(function() {
                    if (loader) loader.hide();
                    modal.hide();
                })
                .done(function(data, textStatus, jqXHR) {
                    var docHeight = $(document).height();
                    $("body").append("<div id='overlay'></div>");
                    $("#overlay")
                        .css({
                            'opacity' : 0.4,
                            'position': 'absolute',
                            'top': 0,
                            'left': 0,
                            'background-color': 'black',
                            'width': '100%',
                            'height': '100%',
                            'z-index': 9999
                        });
                })
                .fail(function(jqXHR) {
                    if (loader) loader.hide();
                    section.stop();
                    section.fadeTo('fast', 1.0);
                    var status_msg = getStatusMsg(jqXHR);
                    showPermanentError($("#section .table"), status_msg);
                });
            });
    });

    $('#section').on('click', '[data-href-background]', function() {
        var that = $(this);
        var href = that.attr('data-href-background');
        var section = $('#section');
        var loader = section.prev('.loader');
        if (loader) loader.show();
        section.fadeTo('fast', 0.5);
        $.ajax(href)
            .done(function(data, textStatus, jqXHR) {
                /*If the status is accepted then wait for 60 seconds to refresh the page */
                if (jqXHR.status == 202) {
                    if (loader) loader.hide();
                    section.stop();
                    section.fadeTo('fast', 1.0);
                    delayedRefresh(5);
                } else {
                    $(window).hashchange();
                }
            })
            .fail(function(jqXHR) {
                if (loader) loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError($("#section .table"), status_msg);
            });
        return false;
    });

    /* Hash change handler */
    var href =  $('.sidebar-nav .nav-list a').first().attr('href');
    if(href) {
        href = href.replace(/^.*#/,"/");
    } else {
        href = "/graph/dashboard/";
    }
    $(window).hashchange(pfOnHashChange(updateSection,href));
    $(window).hashchange();
    activateNavLink();
}
