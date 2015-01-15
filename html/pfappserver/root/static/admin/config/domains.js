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
            showSuccess($('#section h2'), data.status_msg);
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
