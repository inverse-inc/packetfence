closest(document.querySelector('label[for="aup"]'), function (el) { return el.tagName.toLowerCase() === 'div' }))
  .addEventListener('click', function (event) {
    event.preventDefault();
    document.getElementById('aup').setAttribute('checked', 'checked');
    document.getElementById('button').click();
    return false;
  });
