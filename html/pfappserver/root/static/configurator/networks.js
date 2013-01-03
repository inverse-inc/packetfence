function initModals() {
    var interfaces = new Interfaces();
    new InterfaceView({ interfaces: interfaces, parent: $('#section') });
}

function registerExits() {
    $('#tracker a, .form-actions button').click(function(event) {
        event.preventDefault();
        var href = $(this).attr('href');
        saveStep(href);
    });
}

function saveStep(href) {
    var form = $('form[name="networks"]');
    var section = $('#section');
    var errorSibling = section.find('h3:first');

    resetAlert(section);
    var valid = isFormValid(form);
    if (true) {
        $.ajax({
            type: 'POST',
            url: window.location.pathname,
            data: form.serialize()
        }).done(function(data) {
            window.location.href = href;
        }).fail(function(jqXHR) {
            var status_msg = getStatusMsg(jqXHR);
            showError(errorSibling, status_msg);
        });
    }
    else {
        showError(errorSibling, 'You must specifiy a DNS address.');
    }
}
