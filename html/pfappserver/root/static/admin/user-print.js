  $('[name="with-aup"]').change(function(){
    if($(this).prop('checked')) {
      $('.page-break').removeClass('hidden');
      $('dd.aup').removeClass('hidden');
    }
    else {
      $('dd.aup').addClass('hidden');
      $('.page-break').each(function(){
        if(parseInt($(this).data('index')) % 4 != 3) {
          $(this).addClass('hidden');
        }
      });
    }
  });
  $('#print_user').on('click', function() {
    window.print();
  });
