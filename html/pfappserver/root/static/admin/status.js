/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

var refresh = {
    timeout: null,
    startDate: null,
    endDate: null,
    callback: reloadGraphs,
    delay: 60000 // in miliseconds
};

/*
* This function is called at the initial loading of the page or when the window is resized.
* In both cases, the default URL of the hashchange handler must be updated.
* @see graphs.js
*/
function drawGraphs(options) {
    var default_href, pos,
    links = $('.sidenav .nav-list a[href*="graph"]'),
    width = $('#section').width() - 40;

    links.each(function() {
        // Add window width to graph links
        var a = $(this);
        var href = a.attr('href');
        pos = href.indexOf('?');
        if (pos >= 0) href = href.substring(0, pos);
        href += '?width=' + width;
        if (!default_href) default_href = href;
        a.attr('href', href);
    });

    // Register hashchange handler with adjusted parameter (window width)
    if (location.hash.length > 0) {
        default_href = location.hash;
        pos = default_href.indexOf('?');
        if (pos >= 0)
        default_href = default_href.substring(0, pos);
        default_href = default_href.replace(/^.*#/,"/") + '?width=' + width;
        $(window).unbind('hashchange');
    }
    $(window).hashchange(pfOnHashChange(updateSection, default_href));

    if (options && options.noreload) {
        reloadGraphs({ delayed: true });
    } else {
        reloadGraphs();
    }
}

/**
* Update the source URL of graph images and repeat in X seconds
*/
function reloadGraphs(options) {
    if (!options || !options.delayed) {
        var d = new Date();
        $('#section img[data-src-base]').each(function() {
            var that = $(this);
            that.attr('src', that.attr('data-src-base') + '&lastrefresh=' + d.getTime());
        });
    }

    if (refresh.timeout) {
        window.clearTimeout(refresh.timeout);
    }
    refresh.timeout = window.setTimeout(refresh.callback, refresh.delay);
}

function getDates() {
    var dp = $('#section .input-daterange').data('datepicker');
    var start = $(dp.inputs[0]).datepicker('getDate');
    var startDate = [start.getUTCFullYear(), (start.getUTCMonth() + 1), start.getUTCDate()].join('-');
    var end = $(dp.inputs[1]).datepicker('getDate');
    var endDate = [end.getUTCFullYear(), (end.getUTCMonth() + 1), end.getUTCDate()].join('-');

    return { start: startDate, end: endDate };
}

function init() {
    $(window).on('resize', function(event) {
        // When resizing the window, rebuild the graphs after a delay of 100 miliseconds
        if (refresh.timeout) window.clearTimeout(refresh.timeout);
        refresh.timeout = window.setTimeout(drawGraphs, 1000);
    });

    $('#section').on('section.loaded', function(event) {
        var section = $(this);
        if (section.children('#systemstate, #logstate').length) {
            // Set the end date of the range datepickers to today
            var today = new Date();
            $('.input-daterange input').each(function() {
                $(this).datepicker('setEndDate', today);
            });

            // Extract date range
            var range = getDates();
            refresh.startDate = range.start;
            refresh.endDate = range.end;

            // Set base url of images for automatic refresh (see reloadGraphs function)
            $('#section img').each(function() {
                $(this).attr('data-src-base', this.src);
            });

            // Add window width to quick links of relative dates
            $('#section .navbar a').each(function() {
                var width = $('#section').width() - 40;
                $(this).attr('href', this.href + '?width=' + width);
            });

            // Activate automatic refresh of dashboard images
            drawGraphs({ noreload: true });

            // Refresh button will reload section
            $(this).find('#changeDate').on('click', function(event) {
                event.preventDefault();
                var range = getDates();
                var width = $('#section').width() - 40;
                var initialized = refresh.startDate && refresh.endDate;
                if (range.start != refresh.startDate || range.end != refresh.endDate) {
                    refresh.startDate = range.start;
                    refresh.endDate = range.end;
                    var section = location.hash.split('/')[1];
                    var hash = ['graph', section, range.start, range.end].join('/') + '?width=' + width;
                    location.hash = hash;
                }
            });
        } else if (section.children('#dashboard').length) {
            initDashboard();
        }
    });

    function retryStatusPage(attempt) {
        if (attempt) {
            var section = $('#section');
            var loader = section.prev('.loader');
            if (loader) loader.show();
            section.fadeTo('fast', 0.5);
            $.ajax({
                url: '/service/status'
            }).always(function() {
                if (loader) loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
            }).done(function(data, textStatus, jqXHR) {
                section.find('.input-date').datepicker({ autoclose: true });
                if (section.chosen) {
                    section.find('.chzn-select').chosen();
                    section.find('.chzn-deselect').chosen({allow_single_deselect: true});
                }
                if (section.bootstrapSwitch) {
                    section.find('.switch').bootstrapSwitch();
                }
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
        var timerId = setInterval(function() {
            if(timeout > 0) {
                timeout--;
                alert_section.find('span').first().html(timeout.toString());
            }
        }, 1000);
        var doRefresh = function() {
            clearInterval(timerId);
            alert_section.remove();
            retryStatusPage(attempt);
        };
        var refreshTimeoutId = setTimeout(function() {
            alert_section.find('.btn').off('click.refresh');
            doRefresh();
        }, timeout * 1000);
        alert_section.find('.btn').on('click.refresh',function() {
            clearTimeout(refreshTimeoutId);
            doRefresh();
        });
    }

    $("#section").on('click.modal.data-api', '[data-toggle="modal"][data-target][data-confirm-stop-href]', function (e) {
        var that = $(this);
        var href = that.attr("data-confirm-stop-href");
        var modal = $(that.attr("data-target"));
        modal.find(".btn-primary").first().on('click',function(e){
            var section = $('#section');
            var loader = section.prev('.loader');
            if (loader) loader.show();
            $.ajax({
                url: href
            }).always(function() {
                if (loader) loader.hide();
                modal.hide();
            }).done(function(data, textStatus, jqXHR) {
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
            }).fail(function(jqXHR) {
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
        $.ajax({
            url: href
        }).done(function(data, textStatus, jqXHR) {
            /*If the status is accepted then wait for 60 seconds to refresh the page */
            if (jqXHR.status == 202) {
                if (loader) loader.hide();
                section.stop();
                section.fadeTo('fast', 1.0);
                delayedRefresh(5);
            } else {
                $(window).hashchange();
            }
        }).fail(function(jqXHR) {
            if (loader) loader.hide();
            section.stop();
            section.fadeTo('fast', 1.0);
            var status_msg = getStatusMsg(jqXHR);
            showPermanentError($("#section .table"), status_msg);
        });
        return false;
    });

    $('#section').on('click', '[data-restart-admin]', function() {
        var that = $(this);
        var href = that.attr('data-restart-admin');
        var section = $('#section');
        var modal = $('#confirmRestart');
        modal.find(".btn-primary").one('click', function(e) {
            $.ajax({
                url: href
            }).done(function(data, textStatus, jqXHR) {
                /*If the status is accepted then wait for 60 seconds to refresh the page */
                if (jqXHR.status == 202) {
                    delayedRefresh(5);
                } else {
                    $(window).hashchange();
                }
            }).fail(function(jqXHR) {
                var status_msg = getStatusMsg(jqXHR);
                showPermanentError($("#section .table"), status_msg);
            });
        });
        modal.modal('show');
        return false;
    });

    /* Hash change handler */
    var href =  $('.sidebar-nav .nav-list a').first().attr('href');
    if (href) {
        href = href.replace(/^.*#/,"/");
    } else {
        href = "/graph/dashboard/";
    }
    $(window).hashchange(pfOnHashChange(updateSection, href));
    $(window).hashchange();
}

function initDashboard() {
    // Retrieve members of cluster
    var clusterEl = document.getElementById('cluster');
    var cluster = JSON.parse(clusterEl.textContent || clusterEl.innerHTML);

    /* Hide missing charts */
    $('[data-hide-missing]').each(function (index) {
        var $chartEl = $(this);
        $.ajax({
            url: $chartEl.data('host') + '/api/v1/chart?chart=' + $chartEl.data('netdata'),
            method: 'GET',
        }).fail(function (data) {
            $chartEl.hide();
        }).done(function (response) {
            // No error, show the graph
            $chartEl.show();
        });
    });

    /* Fetch alarms */
    getAlarms();
    var alarmsInterval = setInterval(getAlarms, 10000);

    function getAlarms() {
        var colors = {
            warning: {
                color: '#c09853',
                background: '#fcf8e3'
            },
            critical: {
                color: '#b94a48',
                background: '#f2dede'
            }
        };
        $.each(cluster, function (hostname, ip) {
            $.ajax({
                url: '/netdata/' + ip + '/api/v1/alarms',
                method: 'GET'
            }).done(function (response) {
                var alarms = response.alarms;
                $.each(alarms, function (name, alarm) {
                    var el = $('#_' + alarm.id);
                    var status = alarm.status.toLowerCase();
                    var label = alarm.chart.split('.')[0].replace(/_/g, ' ') + ' - ' + alarm.family;
                    var isInitialized = true;
                    if (!el.get(0)) {
                        el = $('[data-alarm="' + status + '"]').clone();
                        isInitialized = false;
                        el.removeAttr('data-alarm');
                        el.attr('id', '_' + alarm.id);
                        $('#alarms').append(el);
                    }
                    if (!el.get(0)) {
                        clearInterval(alarmsInterval);
                        return;
                    }
                    var hostnameEl = el.find('[data-block="hostname"]'); hostnameEl.html(hostname);
                    var labelEl = el.find('[data-block="label"]'); labelEl.html(label);
                    var valueEl = el.find('[data-block="value"]'); valueEl.html(alarm.value_string);
                    if (!isInitialized) {
                        // Append sparkline
                        var sparkline = $(['<div data-netdata="' + alarm.chart + '"',
                        '     data-chart-library="sparkline"',
                        '     data-sparkline-linecolor="' + colors[status].color + '"',
                        '     data-sparkline-fillcolor="' + colors[status].background + '"',
                        '     data-height="30"',
                        '     data-after="-300"></div>'].join(''));
                        el.find('.alert').append(sparkline);
                        fitty(hostnameEl[0], { minSize: 8, maxSize: 11 });
                        fitty(labelEl[0], { minSize: 8, maxSize: 14 });
                        fitty(valueEl[0], { maxSize: 24 });
                        el.removeClass('hide');
                    }
                });
                window.NETDATA.parseDom();
            });
        });
    }
}
