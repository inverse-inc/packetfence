var domainView;
$(function() { // DOM ready
    var items = new Domains();
    domainView = new DomainView({ items: items, parent: $('#section') });
});

/*
 * The FloatingDevices class defines the operations available from the controller.
 */
var Domains = function() {
};

Domains.prototype = new Items();
Domains.prototype.id  = '#domains';
Domains.prototype.formName  = 'modalDomain';
Domains.prototype.modalId   = '#modalDomain';


var DomainView = function(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;
};

DomainView.prototype = (function(){
    function F(){};
    F.prototype = ItemView.prototype;
    return new F();
})();

DomainView.prototype.constructor = ItemView;

DomainView.prototype.showWait = function(title) {
  var that = this;
  $('#modalDomainWait h3').html(title); 
  $('#modalDomainWait').modal('show');
  $('#domainProgressBar').css('width', '1%');
}

DomainView.prototype.updateItem = function(e) {
  e.preventDefault();

  var that = this;
  var form = $(e.target);
  var table = $(this.items.id);
  var btn = form.find('.btn');
  var modal = form.closest('.modal');
  var valid = isFormValid(form);
  if (valid) {
      var modal_body = modal.find('.modal-body').first();
      resetAlert(modal_body);
      form.find('tr.hidden :input').attr('disabled', 'disabled');
      modal.modal('hide');
      that.showWait("The server is currently joining the domain");
      this.items.post({
          url: form.attr('action'),
          data: form.serialize(),
          always: function() {
              // Restore hidden/template rows
              form.find('tr.hidden :input').removeAttr('disabled');
              btn.button('reset');
              $('#modalDomainWait').modal('hide');          
          },
          success: function(data) {
              var content = $('<div></div>');
              content.append('<h3>Result of the domain join</h3>'); 
              content.append($('<pre>'+data.items['join_output']+'</pre>')); 
              that.showResultModal(content); 
              that.list();
          },
          errorSibling: $('#section')
      });
  }
};

DomainView.prototype.showResultModal = function(title, content){
  var self = this;
  
  $('#modalDomainInfo .modal-header h3').html(title);
  $('#modalDomainInfo .modal-body').html(content);
  $('#modalDomainInfo').modal('show');
} 

$(document).ready(function(){
  $('#section').on('click', '.rejoin_domain', function(event){
    event.preventDefault()
    var jbtn = $(this);
    var initial_content = jbtn.html();
    jbtn.attr('disabled', 'disabled');
    // needs to be i18ned 
    jbtn.html("Rejoining domain");
    domainView.showWait("The server is rejoining the domain.");
    $.ajax({
        'url'   : jbtn.attr('href'),
        'type'  : "GET",
        })
        .success(function(data) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var content = $('<div></div>');
            content.append('<h3>Result of the domain leave</h3>'); 
            content.append($('<pre>'+data.items['leave_output']+'</pre>')); 
            content.append('<h3>Result of the domain join</h3>'); 
            content.append($('<pre>'+data.items['join_output']+'</pre>')); 
            $('#modalDomainWait').modal('hide');
            domainView.showResultModal(content); 
            jbtn.html(initial_content);
            jbtn.removeAttr('disabled');
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
            jbtn.html(initial_content);
            jbtn.removeAttr('disabled');
        });
    return false;
  });

  $('#section').on('click', '#refresh_domains', function(event){
    
    event.preventDefault()
    var initial_content = $('#refresh_domains').html();
    $('#refresh_domains').attr('disabled', 'disabled');
    // need to be i18ned 
    $('#refresh_domains').html("Refreshing domains");
    domainView.showWait("The server is refreshing the configuration.");
    $.ajax({
        'url'   : $('#refresh_domains').attr('href'),
        'type'  : "GET",
        })
        .success(function(data) {
            $("body,html").animate({scrollTop:0}, 'fast');
            $('#modalDomainWait').modal('hide');
            showSuccess($('#section h2'), data.status_msg);
            $('#refresh_domains').html(initial_content);
            $('#refresh_domains').removeAttr('disabled');
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            showError($('#section h2'), status_msg);
            $('#refresh_domains').html(initial_content);
            $('#refresh_domains').removeAttr('disabled');
        });
    });

  setInterval(function(){
    var width = $('#domainProgressBar').width();
    if(!width && width !== 0) return; 
    var parentWidth = $('#domainProgressBar').offsetParent().width();
    var width = 100*width/parentWidth;
    if(width == 100){
      width = 0;
    }
    else{
      width += 10;
      if(width > 100){
        width = 100;
      }
    }
    $('#domainProgressBar').css('width', width+'%');
  }, 15000);

})
