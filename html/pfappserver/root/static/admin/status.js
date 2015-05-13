var refresh = {
    timeout: null,
    callback: reloadGraphs,
    delay: 60000 // in miliseconds
};

/*
 * This function is called at the initial loading of the page or when the window is resized.
 * In both cases, the default URL of the hashchange handler must be updated.
 * @see graphs.js
 */
function drawGraphs() {

    var href, pos,
      a = $('.sidebar-nav .nav-list a').first(),
      width = $('#dashboard').width();

    if (a) {
        // Add window width to dashboard link
        href = a.attr('href');
        pos = href.indexOf('?');
        if (pos >= 0)
            href = href.substring(0, pos);
        href += '?width=' + width;
        a.attr('href', href);
    }

    // Register hashchange handler with adjusted parameter (window width)
    if (location.hash.length > 0) {
        href = location.hash, pos = href.indexOf('?');
        if (pos >= 0)
            href = href.substring(0, pos);
        href = href.replace(/^.*#/,"/") + '?width=' + width;
        $(window).unbind('hashchange');
    }
    $(window).hashchange(pfOnHashChange(updateSection, href));

    // Trigger all event handlers with new hash that includes window width
    location.hash = href.replace(/^[#/]/, '');
}

function reloadGraphs() {
    var d = new Date();
    $('#dashboard img').each(function() {
        var that = $(this);
        that.attr('src', that.attr('data-src-base') + '&lastrefresh=' + d.getTime());
    });

    if (refresh.timeout)
        window.clearTimeout(refresh.timeout);
    refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
}

function init() {

    /* Reload dashboard when changing date */
    $('body').on('changeDate', '.input-daterange input', function(event) {
        var dp = $(this).closest('.datepicker').data('datepicker');
        var start = dp.dates[0];
        var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
        var end = dp.dates[1];
        var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');
        var width = $('#dashboard').width();
        location.hash = ['graph', 'dashboard', startDate, endDate].join('/') + '?width=' + width;
    });

    /* Automatically refresh dashboard every X seconds */
    $('#section').on('section.loaded', function(event) {
        var section = $(this);
        if (section.children('#dashboard').length) {
            // Set the end date of the range datepickers to today
            var today = new Date();
            $('.datepicker').find('input').each(function() { $(this).data('datepicker').setEndDate(today) });

            // Set base url of images for automatic refresh (see reloadGraphs function)
            $('#dashboard img').each(function() {
                $(this).attr('data-src-base', this.src);
            });

            // Add window width to quick links of relative dates
            $('#dashboard .navbar a').each(function() {
                $(this).attr('href', this.href + '?width=' + $('#dashboard').width());
            });

            // Activate automatic refresh
            if (refresh.timeout)
                window.clearTimeout(refresh.timeout);
            refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
        }
        else {
            window.clearTimeout(refresh.timeout);
        }
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
    drawGraphs();
    activateNavLink();
}
