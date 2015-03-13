var view;
$(function() { // DOM ready
    var items = new Domains();
    view = new DomainView({ items: items, parent: $('#section') });
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

DomainView.prototype.constructor = FloatingDeviceView;

ItemView.prototype.updateItem = function(e) {
    e.preventDefault();

    var that = this;
    var form = $(e.target);
    var table = $(this.items.id);
    var btn = form.find('.btn-primary');
    var modal = form.closest('.modal');
    var valid = isFormValid(form);
    if (valid) {
        var modal_body = modal.find('.modal-body').first();
        resetAlert(modal_body);
        btn.button('loading');
        form.find('tr.hidden :input').attr('disabled', 'disabled');
        this.items.post({
            url: form.attr('action'),
            data: form.serialize(),
            always: function() {
                // Restore hidden/template rows
                form.find('tr.hidden :input').removeAttr('disabled');
                btn.button('reset');
            },
            success: function(data) {
                modal.modal('toggle');
                var content = $('<div></div>');
                content.append('<h3>Result of the domain join</h3>'); 
                content.append($('<pre>'+data.items['join_output']+'</pre>')); 
                that.showResultModal(content); 
                that.list();
            },
            errorSibling: modal_body.children().first()
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
    $.ajax({
        'url'   : jbtn.attr('href'),
        'type'  : "GET",
        })
        .success(function(data) {
            console.log(data);
            $("body,html").animate({scrollTop:0}, 'fast');
            var content = $('<div></div>');
            content.append('<h3>Result of the domain leave</h3>'); 
            content.append($('<pre>'+data.items['leave_output']+'</pre>')); 
            content.append('<h3>Result of the domain join</h3>'); 
            content.append($('<pre>'+data.items['join_output']+'</pre>')); 
            view.showResultModal(content); 
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
    console.log("hello")
    
    event.preventDefault()
    var initial_content = $('#refresh_domains').html();
    $('#refresh_domains').attr('disabled', 'disabled');
    // need to be i18ned 
    $('#refresh_domains').html("Refreshing domains");
    $.ajax({
        'url'   : $('#refresh_domains').attr('href'),
        'type'  : "GET",
        })
        .success(function(data) {
            console.log(data);
            $("body,html").animate({scrollTop:0}, 'fast');
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
    return false;
})
