$(function () {
    $('[href=#testDatabase], [href=#createUser]').click(function(event) {
        $(this).closest('.control-group').prevUntil('h3').andSelf().each(function(index) {
            var e = $(this);
            if (e.find('input').first().val().trim().length == 0)
                e.addClass('error');
            else
                e.removeClass('error');
        });
    });
});