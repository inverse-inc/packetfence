/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

var domainView;
$(function() { // DOM ready
    var items = new Domains();
    domainView = new DomainView({ items: items, parent: $('#section') });
});

/*
 * The FloatingDevices class defines the operations available from the controller.
 */
function Domains() {
}

Domains.prototype = new Items();
Domains.prototype.id  = '#domains';
Domains.prototype.formName  = 'modalDomain';
Domains.prototype.modalId   = '#modalDomain';
Domains.prototype.createSelector = ".createDomain";


function DomainView(options) {
    ItemView.call(this,options);
    var that = this;
    this.parent = options.parent;
    this.items = options.items;

    var id = this.items.id;

    options.parent.off('click', id + ' [href$="/delete"]');

    var delete_item = $.proxy(this.deleteItem, this);
    options.parent.on('click', id + ' [href$="/delete"]', delete_item);

    var save_and_join = $.proxy(this.updateAndJoinDomain, this);
    options.parent.on('click', '#saveAndJoinDomain', save_and_join);
}

DomainView.prototype = (function(){
    function F(){}
    F.prototype = ItemView.prototype;
    return new F();
})();

DomainView.prototype.constructor = ItemView;

DomainView.prototype.showWait = function(title) {
  var that = this;
  $('#modalDomainWait h3').html(title); 
  $('#domainProgressBar').css('width', '1%');
  $('#modalDomainWait').modal('show');
};

DomainView.prototype.updateAndJoinDomain = function(e) {
  e.preventDefault();

  var that = this;
  var target = $(e.target);
  var form = target.closest('form');
  var table = $(this.items.id);
  var btn = form.find('.btn');
  var modal = form.closest('.modal');
  var valid = isFormValid(form);
  if (valid) {
      var modal_body = modal.find('.modal-body').first();
      resetAlert(modal_body);
      id_input = modal_body.find('#id');
      id_value = id_input.val();
      if (!id_value.match(/^[a-zA-Z0-9]+$/)) {
          showError(modal_body, "The id is invalid. The id can only contain alphanumeric characters.");
          return;
      }

      form.find('tr.hidden :input').attr('disabled', 'disabled');
      modal.modal('hide');
      that.showWait("The server is currently joining the domain");
      this.items.post({
          url: target.attr('href'),
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
              content.append($('<pre>' + data.items.join_output + '</pre>'));
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
}; 

DomainView.prototype.deleteItem = function(e) {
  var self = this;
  var original_event = e;
  e.preventDefault();
  if ($(this).hasClass('disabled'))
      return false;
  var link = $(this);
  var url = link.attr('href');
  var row = link.closest('tr');
  var cells = row.find('td');
  var name = $(cells[1]).text();
  if (!name) name = $(cells[0]).text();
  var modal = $('#deleteItem');
  var confirm_link = modal.find('a.btn-primary').first();
  modal.find('h3 span').html(name);
  modal.modal('show');
  confirm_link.off('click');
  confirm_link.click(function(e) {
      e.preventDefault();
      confirm_link.button('loading');

      e.preventDefault();
      var table = $(self.items.id);
      var btn = $(original_event.target);
      var row = btn.closest('tr');
      var url = btn.attr('href');
      self.items.get({
          url: url,
          always: function(){
            confirm_link.button('reset');
            modal.modal('hide');
          },
          success: function(data) {
              showSuccess(table, data.status_msg);
              self.list(e);
          },
          errorSibling: table
      });

  });
};

DomainView.prototype.list = function() {
    var table = $('#domains');
    this.listRefresh(table.attr('data-list-uri'));
};

DomainView.prototype.listRefresh = function(list_url) {
    var table = $('#domains');
    var that = this;
    table.fadeTo('fast',0.5,function() {
        that.items.get({
            url: list_url,
            always: function() {
                table.fadeTo('fast',1.0);
            },
            success: function(data) {
                table.replaceWith(data);
            },
            errorSibling: $('#domains')
        });
    });
};

DomainView.prototype.setPassword = function(domain,callback) {
  var that = this;
  var modal = $('#modalDomainSetPassword-'+domain);
  var form = $('#modalDomainSetPassword-'+domain+' form');
  form.submit(function(evt){
    evt.preventDefault();
    $.ajax({
        'url'   : form.attr('action'),
        'type'  : "POST",
        'data'  : form.serialize(),
        })
        .done(function(data) {
            modal.modal('hide');     
            form.find('input[name="username"]').val('');
            form.find('input[name="password"]').val('');
            callback();
        })
        .fail(function(jqXHR) {
            $("body,html").animate({scrollTop:0}, 'fast');
            var status_msg = getStatusMsg(jqXHR);
            form.find('input[name="username"]').val('');
            form.find('input[name="password"]').val('');
            showError($('#section h2'), status_msg);
        });
    return false;
  });
  modal.modal('show');
};

$(document).ready(function(){
  $('#section').on('click', '.rejoin_domain', function(event){
    var that = this;
    event.preventDefault();
    var domain_name = $(event.target).parent().parent().children().children().html();
    domainView.setPassword(domain_name, function(){
      var view = domainView;
      var jbtn = $(that);
      var initial_content = jbtn.html();
      jbtn.attr('disabled', 'disabled');
      // needs to be i18ned 
      jbtn.html("Rejoining domain");
      domainView.showWait("The server is rejoining the domain.");
      $.ajax({
          'url'   : jbtn.attr('href'),
          'type'  : "GET",
          })
          .done(function(data) {
              $("body,html").animate({scrollTop:0}, 'fast');
              var content = $('<div></div>');
              content.append('<h3>Result of the domain leave</h3>'); 
              content.append($('<pre>'+data.items.leave_output+'</pre>'));
              content.append('<h3>Result of the domain join</h3>'); 
              content.append($('<pre>'+data.items.join_output+'</pre>'));
              $('#modalDomainWait').modal('hide');
              domainView.showResultModal(content); 
              view.list();
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
    });
    return false;
  });

  $('#section').on('click', '#refresh_domains', function(event){
    
    event.preventDefault();
    var initial_content = $('#refresh_domains').html();
    $('#refresh_domains').attr('disabled', 'disabled');
    // need to be i18ned 
    $('#refresh_domains').html("Refreshing domains");
    domainView.showWait("The server is refreshing the configuration.");
    $.ajax({
        'url'   : $('#refresh_domains').attr('href'),
        'type'  : "GET",
        })
        .done(function(data) {
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
    width = 100*width/parentWidth;
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

});
