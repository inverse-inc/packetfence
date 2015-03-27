
$(function() { // DOM ready
/* Perfom an advanced search */
$('#section').on('submit','#fingerbankonboard', function(event) {
    alert("blah blah");
    updateSectionFromForm($('#fingerbankonboard'));
    return false;
});

});
