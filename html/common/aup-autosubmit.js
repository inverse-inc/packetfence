$('label[for="aup"]').closest('div').click(function(e) {
  e.preventDefault();
  $('#aup').attr('checked', 'checked');
  $('#button').click();
  return false;
});
