// replaces jQuery $.ajax()
function ajax(method, url, data, successFn = function(){}, failureFn = function(){}) {
  var xhr = createXMLHTTPObject();
  if (!xhr)
    return;
  xhr.open(method, url, true);
  if (data)
    xhr.setRequestHeader('Content-type','application/x-www-form-urlencoded');
  xhr.onreadystatechange = function () {
    if (xhr.readyState != 4)
      return;
    if (xhr.status < 200 || xhr.status > 399)
      return;
    successFn(xhr);
  }
  if (xhr.readyState == 4)
    return;
  xhr.onerror = failureFn;
  xhr.send(data);
}

var XMLHttpFactories = [
  function () { return new XMLHttpRequest() },
  function () { return new ActiveXObject("Msxml3.XMLHTTP") },
  function () { return new ActiveXObject("Msxml2.XMLHTTP.6.0") },
  function () { return new ActiveXObject("Msxml2.XMLHTTP.3.0") },
  function () { return new ActiveXObject("Msxml2.XMLHTTP") },
  function () { return new ActiveXObject("Microsoft.XMLHTTP") }
];

function createXMLHTTPObject() {
  var xh = false;
  for (var i=0;i<XMLHttpFactories.length;i++) {
    try {
      xh = XMLHttpFactories[i]();
    }
    catch (e) {
      continue;
    }
    break;
  }
  return xh;
}

// replaces jQuery $.closest()
var closest = function (el, fn) {
  return el && (fn(el) ? el : closest(el.parentNode, fn))
}