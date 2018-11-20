$('label[for="aup"]').closest('div').click(function(e) {
  e.preventDefault();
  $('#aup').attr('checked', 'checked');
  $(this).closest('form').submit(); 
  return false;
});
