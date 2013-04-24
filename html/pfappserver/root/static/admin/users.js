$(function() { // DOM ready
    var users = new Users();
    var view = new UserView({ users: users, parent: $('#section') });
});

function init() {
    $(window).hashchange(pfOnHashChange(updateSection,'/user'));
    $(window).hashchange();
}

