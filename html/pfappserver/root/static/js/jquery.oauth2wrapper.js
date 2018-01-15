;(function( $, window, undefined ) {

    var Plugin = function( element, options ){
        this.element = element;
        this.$element = $(element);
        this.options = options;
        this.metadata = this.$element.data( 'plugin-options' );
    };
    
    Plugin.prototype = {
        defaults: {
            loading_message: 'Loading Oauth2 authorization server, please wait...',
            authorize_uri: 'http://httpbin.org/post',
            authorize_post: {},
            authorize_callback: console.log
        },

        init: function() {
            this.config = $.extend( {}, this.defaults, this.options, this.metadata );
            //add event listener on element
            this.$element.on('click', $.proxy(this.authorize, this));
            //cross-origin communication event listener (CORS workaround).
            window.addEventListener("message", $.proxy(this.message, this), false);
        },
        
        authorize: function() {
            //enforce singleton
            if(typeof(this.modal) != 'undefined' && ! this.modal.closed){
                this.modal.close();
            };
            //open window
            this.modal = window.open('', 'oauth2', 'location=yes,menubar=no,resizable=yes,scrollbars=yes,status=yes,titlebar=yes,toolbar=no', false);
            //write document
            var html_post = '';
            $.each(this.config.authorize_post, function(k,v){
                html_post+='<input type="hidden" name="'+k+'" value="'+v+'" />';
            });
            this.modal.document.write('<!doctype html>\n<html><head><title>Oauth2</title></head><body><p>'+this.config.loading_message+'</p><form id="form" method="post" action="'+this.config.authorize_uri+'">'+html_post+'</form></body></html>');
            $(this.modal.document).find('#form').submit();
        },
  
        token: function(code) {
            
            /* 
             * WORK IN PROGRESS - Darren Satkunas - Jan 15th, 2018
             */
            /*
            //enforce singleton
            if(typeof(this.modal) != 'undefined' && ! this.modal.closed){
                this.modal.close();
            };
            //open window
            this.modal = window.open('', 'oauth2', 'location=yes,menubar=no,resizable=yes,scrollbars=yes,status=yes,titlebar=yes,toolbar=no', false);
            //write document
            var html_post = '';
            $.each(this.config.token_post, function(k,v){
                if(k=='code'){ v=code; }
                html_post+='<input type="hidden" name="'+k+'" value="'+v+'" />';
            });
            this.modal.document.write('<!doctype html>\n<html><head><title>Oauth2</title></head><body><p>'+this.config.loading_message+'</p><form id="form" method="post" action="'+this.config.token_uri+'">'+html_post+'</form></body></html>');
            $(this.modal.document).find('#form').submit();
            */
           
            /*
            $.ajax({
                type: 'POST',
                url: 'https://login.microsoftonline.com/common/oauth2/token',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                dataType: 'json',
                data: {
                    'grant_type': 'authorization_code',
                    'client_id': 'd6f68181-eff0-44f4-be2c-0e989b718150', 
                    'client_secret': 'o5FtvqImK/krpMn9olng3IXMnHy5YyZ2LK5ja9iAjio=', 
                    'scope': 'offline_access+https://graph.microsoft.com/Device.ReadWrite.All',
                    'code': code,
                    'redirect_uri': 'http://localhost:65010/oauth2/callback',
                    'resource': 'https://api.manage.microsoft.com/',
                    'state': 'test'          
                },
                success : function (data) {
                    console.log(data);
                },
                error : function (data, errorThrown) {
                    console.log([data,errorThrown]);
                }                
            });
            */
            
            
            
        },
        
        message: function(event){
            var json = JSON.parse('{"' + decodeURI(event.data.replace(/&/g, "\",\"").replace(/=/g,"\":\"")) + '"}');
            if(typeof(json.code) !== 'undefined') {
                event.source.close();
                this.config.authorize_callback(json);
                //this.token(json.code);
                return;
            }
        }
    };

    Plugin.defaults = Plugin.prototype.defaults;
    $.fn.oauth2wrapper = function(options) {
        return this.each(function() {
            new Plugin(this, options).init();
        });
    };
})( jQuery, window );
