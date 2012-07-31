$(function () {
    /* Register tracker tooltips */
    $('#tracker [rel=tooltip]').tooltip({placement: 'bottom'});

    if (typeof initModals == 'function') initModals();
    if (typeof initStep == 'function') initStep();
    if (typeof registerExits == 'function') registerExits();
});