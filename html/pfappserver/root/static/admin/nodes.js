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

    /* Register clicks on pre-defined periods */

    /* Hash change handlder */
    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));
    $(window).hashchange();
}