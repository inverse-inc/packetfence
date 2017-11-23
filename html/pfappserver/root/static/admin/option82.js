$(function() { // DOM ready
    var view = new DHCPOption82View({ items: new Items(), parent: $('#section') });
});

/*
 * The DHCPOption82View class defines the DOM operations from the Web interface.
 */

var DHCPOption82View = function(options) {
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
    var resetSearch = $.proxy(this.resetSearch, this);
    options.parent.on('click', '#dhcpoption82_reset', resetSearch);
};

DHCPOption82View.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

DHCPOption82View.prototype.resetSearch = function(e) {
    e.preventDefault();
    var form = $('form[name="search"]');
    form.find('select[name="per_page"]').val('25');
    form.find('select[name="all_or_any"]').val('all');
    $('#searchConditions').find('tbody').children(':not(.hidden)').find('[href="#delete"]').click();
    form.submit();
};
