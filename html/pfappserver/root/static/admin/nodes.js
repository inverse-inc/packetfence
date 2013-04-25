$(function() { // DOM ready
    var nodes = new Nodes();
    var view = new NodeView({ nodes: nodes, parent: $('#section') });

    var users = new Users();
    var view = new UserView({ users: users, parent: $('#section') });
});

function init() {
    $(window).hashchange(pfOnHashChange(updateSection,'/node/'));
    $(window).hashchange();
}
