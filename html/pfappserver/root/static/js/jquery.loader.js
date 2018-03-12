/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 4 -*- */

(function( $ ) {
    
    $.fn.loader = function(action) {

        var element = this.find('.loader');
        if (element.length === 0 && (!action || action != 'hide')) {
            element = $('<div class="loader"><div><i class="icon"></i></div></div>');
            this.css('position', 'relative');
            this.css('min-height', '200px');
        }
        if (action == 'hide')
            element.hide();
        else {
            this.append(element);
            element.fadeTo('fast', 1.0);
        }

        return this;
        
    };
    
}( jQuery ));
