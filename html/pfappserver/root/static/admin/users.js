$(function() { // DOM ready
    var users = new Users();
    var view = new UserView({ users: users, parent: $('#section') });
});

function init() {
    /* Handle saved searches */
    $("#modalUser").on('show', '[data-toggle="tab"][data-target][href]', function(event) {
        var that = $(this);
        var target = $(that.attr("data-target"));
        target.load(that.attr("href"));
        return true;
    });

    $(window).hashchange(pfOnHashChange(updateSection,'/user'));

    $(window).hashchange();
}

