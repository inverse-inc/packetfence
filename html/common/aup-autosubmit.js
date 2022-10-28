closest(document.querySelector('label[for="aup"]'), function (el) { return el.tagName.toLowerCase() === 'div' })
  .addEventListener('click', function (event) {
    event.preventDefault();
    var aup = document.getElementById('aup');
    aup.setAttribute('checked', 'checked');
    HTMLFormElement.prototype.submit.call(aup.closest('form'));
    return false;
  });
