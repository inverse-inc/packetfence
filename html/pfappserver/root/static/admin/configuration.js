function init() {

    /* Save a section */
    $('#section').on('submit', 'form[name="section"]', function(event) {
        var form = $(this);
        var url = form.attr('action');
        var valid = isFormValid(form);

        if (valid) {
            $.ajax({
                type: 'POST',
                url: url,
                data: form.serialize()
            })
            .always(function() {
                $("body,html").animate({scrollTop:0}, 'fast');
                resetAlert($('#section'));
            })
            .done(function(data) {
                showSuccess(form, data.status_msg);
            })
            .fail(function(jqXHR) {
                var status_msg;
                try {
                    var obj = $.parseJSON(jqXHR.responseText);
                    status_msg = obj.status_msg;
                }
                catch(e) {
                    status_msg = "Cannot submit form";
                }
                showPermanentError(form, status_msg);
            });
        }

        return false;
    });

    /* Set the focus on the first editable and visible field */
    $('#section').on('section.loaded', function(event) {
        $(':input:visible:enabled:first').focus();
    });

    $(window).hashchange(pfOnHashChange('/',updateSection,'/configuration'));

    $(window).hashchange();

    activateNavLink();
}

/*
 * Update an action input field depending on the selected action type.
 * Used in
 * - configuration/authentication.js
 * - configuration/users.js
 */
function updateAction(type) {
    var action = type.val();
    var value = type.next();

    // Replace value field with the one from the templates
    var value_new = $('#' + action + '_action').clone();
    value_new.attr('id', value.attr('id'));
    value_new.attr('name', value.attr('name'));
    value_new.insertBefore(value);

    // Remove previous field
    value.remove();

    // Initialize rendering widgets
    initWidgets(value_new);
}

/*
 * Initialize the rendering widgets of some elements
 */
function initWidgets(elements) {
    elements.filter('.chzn-select').chosen();
    elements.filter('.chzn-deselect').chosen({allow_single_deselect: true});
    elements.filter('.timepicker-default').each(function() {
        // Keep the placeholder visible if the input has no value
        var defaultTime = $(this).val().length? 'value' : false;
        $(this).timepicker({ defaultTime: defaultTime, showSeconds: false, showMeridian: false });
    });
    elements.filter('.datepicker').datepicker({ autoclose: true });
}
