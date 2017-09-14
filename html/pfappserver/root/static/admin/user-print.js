  $('[name="with-aup"]').change(function(){
    if($(this).prop('checked')) {
      $('.page-break').removeClass('ignore');
      $('dd.aup').removeClass('ignore');
    }
    else {
      $('.page-break').each(function(){
        if(parseInt($(this).data('index')) % 4 != 3) {
          $(this).addClass('ignore');
          $('dd.aup').addClass('ignore');
        }
      });
    }
  });
  $('#print_user').on('click', function() {
    window.print();
  });
