
var filtersView;
$(function() { // DOM ready
  filtersView = new FiltersView({ parent: $('#section') });
});

var FiltersView = function(options) {
  var that = this;
  this.parent = options.parent;

  // Save the modifications
  var update = $.proxy(this.update, this);
  options.parent.on('submit', '#filtersForm', update);
  
  // Revert the modifications
  var revert = $.proxy(this.revert, this);
  options.parent.on('click', '#filtersRevert', revert);
};

FiltersView.prototype.setupEditor = function(){
  this.editor = ace.edit("editor");
  this.editor.setTheme("ace/theme/monokai");
  this.editor.getSession().setMode("ace/mode/perl");

  this.disableButtons();
  
  this.initialValue = this.editor.getValue();
}

FiltersView.prototype.revert = function(e){
  this.editor.setValue(this.initialValue, -1);
  this.disableButtons();
}

FiltersView.prototype.disableButtons = function() {
  $('#filtersForm .btn').addClass('disabled');
  
  this.enableButtonsProxy = $.proxy(this.enableButtons, this);
  this.editor.on("change",this.enableButtonsProxy);

}

FiltersView.prototype.enableButtons = function() {
  $('#filtersForm .btn').removeClass('disabled');
  this.editor.removeEventListener("change",this.enableButtonsProxy);
}

FiltersView.prototype.update = function(e){
  var that = this;
  e.preventDefault();

  var jthis = $(e.target);
  $.ajax({
      url: jthis.attr("action"),
      type: 'POST',
      data: { content : this.editor.getValue() },
  })
  .done(function(data){
    showSuccess(jthis, data.status_msg);
    that.initialValue = that.editor.getValue();
    that.disableButtons();
  })
  .fail(function(jqXHR) {
      var status_msg = getStatusMsg(jqXHR);
      showPermanentError(jthis, status_msg);
  });

  return false;
}
