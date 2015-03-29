$(function() { // DOM ready
    $('#section').on('submit','#fingerbankonboard', function(event) {
        updateSectionFromForm($('#fingerbankonboard'));
        return false;
    });
});
