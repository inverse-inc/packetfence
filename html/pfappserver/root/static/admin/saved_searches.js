$(function() {
    var modal = $("#saveSearch");
    var button = modal.find('a.btn-primary').first();
    button.off('click');
    button.click(function(event) {
        submitFormHideModal(modal,modal.find("form"));
    });
});
