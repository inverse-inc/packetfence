
var filtersView;
$(function() { // DOM ready
    filtersView = new FiltersView({ parent: $('#section') });
});

var FiltersView = function(options) {
    var that = this;
    this.parent = options.parent;

    // Save the modifications from the modal
    var update = $.proxy(this.update, this);
    options.parent.on('submit', '#filtersForm', update);
};

FiltersView.prototype.setupEditor = function(){
  this.editor = ace.edit("editor");
  this.editor.setTheme("ace/theme/monokai");
  this.editor.getSession().setMode("ace/mode/perl");
}

FiltersView.prototype.update = function(e){
    e.preventDefault();

    var jthis = $(e.target);
    $.ajax({
        url: jthis.attr("action"),
        type: 'POST',
        data: { content : this.editor.getValue() },
    })
    .done(function(data){
      showSuccess(jthis, data.status_msg);
    })
    .fail(function(jqXHR) {
        var status_msg = getStatusMsg(jqXHR);
        showPermanentError(jthis, status_msg);
    });
    return false;

    return false;
}
