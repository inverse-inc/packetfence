$(function() { // DOM ready
    var interfaces = new Interfaces();
    new InterfaceView({ interfaces: interfaces, parent: $('#section') });
});