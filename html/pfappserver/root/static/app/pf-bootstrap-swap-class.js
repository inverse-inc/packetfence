
!function($) {
    var SwapClass = function(element, options) {
        var $element = $(element);
        this.$element = $element;
        this.classes = (($element.attr('class')) + ";" + ($element.attr('data-swap') || "")).split(';');
        this.index = 0;
        this.options = $.extend({}, $.fn.swap_class.defaults, options, this.$element.data());
    };

    SwapClass.prototype = {
        constructor: SwapClass,
        toggle : function() {
            this.swap();
        },
        swap : function(i) {
            var e = $.Event('swap')
            this.$element.trigger(e);
            if(i === undefined) {
                i = this.index + 1;
            }
            i = i % this.classes.length;
            this.$element.attr('class',this.classes[i]);
            this.index = i;
        },

        reset : function() {
            this.swap(0);
        }
    };

    $.fn.swap_class = function (option) {
        return this.each(function () {
            var $this = $(this)
            , data = $this.data('swap_class')
            , options = typeof option == 'object' && option;
            if (!data) {
                $this.data('swap_class', (data = new SwapClass(this, options)));
            }
            if (typeof option == 'string') {
                data[option]();
            }
        })
    }

    $.fn.swap_class.defaults = { };

    $.fn.timepicker.Constructor = SwapClass
    $(document).on('click.swap-class.data-api', '[data-toggle="swap-class"]', function (e) {
      var $this = $(this)
        , $target = $($this.attr('data-target'))
        , option = $target.data('modal') ? 'toggle' : $.extend({}, $target.data(), $this.data())
      e.preventDefault()
      $target.swap_class(option);
    })
}(window.jQuery);
