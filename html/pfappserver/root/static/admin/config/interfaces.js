$(function() { // DOM ready
    var interfaces = new Interfaces();
    var view = new InterfaceView({ interfaces: interfaces, parent: $('#section') });

    var read = $.proxy(view.readInterface, view);
    $('#section').on('click', '#createNetwork', read);
    $('#section').on('click', '#createBond', read);
});
