/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

$(function() { // DOM ready
    var nodes = new Nodes();
    var view = new NodeView({ nodes: nodes, parent: $('#section') });

    var users = new Users();
    var view = new UserView({ users: users, parent: $('#section') });
});

function parseQueryString(queryString) {
    var params = [], queries, temp, i, l;
    queryString.replace(/(^\?)/,'');
    // Split into key/value pairs
    queries = queryString.split("&");
    // Convert the array of strings into an object
    for ( i = 0, l = queries.length; i < l; i++ ) {
        temp = queries[i].split('=');
        params.push({
            name: decodeURIComponent(temp[0]),
            value: decodeURIComponent(temp[1])
        });
    }
    return params;
};

function updateNodeSearchSection(href, event) {
    var hash = location.hash;
    var i;
    if (hash && hash.indexOf("#/node/advanced_search?") == 0) {
        $('[href="#advanced"][data-toggle="tab"]').one('shown', function(e) {
            var win = $(window);
            win.unbind('hashchange');
            hash  = hash.replace(/(^#.*\?)/,''); 
            var new_params = parseQueryString(hash);
            var to_form = $('#advancedSearch');
            var table = to_form.find('table');
            $('#advancedSearchConditionsEmpty').find('[href="#add"]').click();
            var first_row = to_form.find('tbody tr.dynamic-row:not(.hidden)').first();
            first_row.nextAll("tr.dynamic-row:not(.hidden)").remove();
            var rows_to_add = new_params.length / 3 - 1;
            for(i = 0; i < rows_to_add; i++) {
                first_row.find('[href="#add"]').click();
            }

            for(i = 0; i <new_params.length;i++) {
                var param = new_params[i];
                var input = to_form.find('[name="' + param.name + '"]:not(:disabled)');
                input.val(param.value);
            }
            win.hashchange(function() {
                win.unbind('hashchange');
                win.hashchange(pfOnHashChange(updateNodeSearchSection,'/node/'));
            });
            location.hash = '';
            doUpdateSection(href);
        });
        //Show the advanced search tab
        $('[href="#advanced"][data-toggle="tab"]').click();
        return false;
    }
    return doUpdateSection(href);
}

function init() {
    /* Initialize datepickers */
    $('.tab-content .input-date, .tab-content .input-daterange').datepicker({ autoclose: true });
    $('.tab-content .input-daterange input').on('changeDate', function(event) {
        // Force autoclose
        $('.datepicker').remove();
    });

    /* Set the end date of the range datepickers to today */
    var today = new Date();
    $('.tab-content .input-date').each(function() { $(this).data('datepicker').setEndDate(today) });

    /* Submit dropdown menu form when hiding the dropdown menu;
       Used to show or hide columns */
    $('body').on('change', '.dropdown-menu-form input[type="checkbox"]', function(event) {
        var checkbox = $(this);
        if (checkbox.data('dirty'))
            checkbox.removeData('dirty');
        else
            checkbox.data('dirty', 1);
    });

    $('html').on('click.dropdown.data-api', function(event) {
        $('.dropdown-menu-form').each(function() {
            if ($.grep($(this).find('input'), function(n) {
                return typeof $(n).data('dirty') != 'undefined'
            }).length > 0) {
                var parent = this.parentNode;
                if (parent.tagName == 'FORM' && $(parent).hasClass('open')) {
                    $(parent).removeClass('open');
                    if (parent.id == 'columns')
                        // Showing the results of an advanced search;
                        // To refresh the page, trigger a click on the active page of the pagination
                        $('.pagination .disabled a').first().click();
                    else
                        // Showing the results of a simple search;
                        // To refresh the page, submit the current form which contains the filter
                        updateSectionFromForm($(parent));
                }
            }
        });
    });

    $('form[name="simpleNodeSearch"] [name$=".name"]').trigger('saved_search.loaded');
    $('form[name="simpleNodeSearch"] [name$=".op"]').trigger('saved_search.loaded');

    /* Hash change handlder */
    var win = $(window);
    win.hashchange(pfOnHashChange(updateNodeSearchSection,'/node/'));
    win.hashchange();
}
