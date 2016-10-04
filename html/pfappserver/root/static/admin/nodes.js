$(function() { // DOM ready
    var nodes = new Nodes();
    var view = new NodeView({ nodes: nodes, parent: $('#section') });

    var users = new Users();
    var view = new UserView({ users: users, parent: $('#section') });
});

function init() {
    /* Initialize datepickers */
    $('.tab-content .datepicker').datepicker({ autoclose: true });

    /* Set the end date of the range datepickers to today */
    var today = new Date();
    $('.tab-content .datepicker input').each(function() { $(this).data('datepicker').setEndDate(today) });

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

    $('form[name="advancedNodeSearch"] [name$=".name"]').trigger('saved_search.loaded');
    $('form[name="advancedNodeSearch"] [name$=".op"]').trigger('saved_search.loaded');
    $('form[name="simpleNodeSearch"] [name$=".name"]').trigger('saved_search.loaded');
    $('form[name="simpleNodeSearch"] [name$=".op"]').trigger('saved_search.loaded');

    /* Hash change handlder */
    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));
    $(window).hashchange();
}
