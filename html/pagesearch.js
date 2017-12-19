/*
 * PageSearch
 */
(function($) {
    'use strict';
    
    function findGetParameter(parameterName) {
        var result = null,
            tmp = [];
        location.search
            .substr(1)
            .split("&")
            .forEach(function (item) {
              tmp = item.split("=");
              if (tmp[0] === parameterName) result = decodeURIComponent(tmp[1]);
            });
        return result;
    }
    
    function findReplaceParameter(parameterName, val) {
        var result = [],
            tmp = [],
            isexists = 0;
        location.search
            .substr(1)
            .split("&")
            .forEach(function (item) {
              tmp = item.split("=");
              if (tmp[0] === parameterName) {
                isexists = 1;
                tmp[1] = encodeURIComponent(val);
              }
              result.push(tmp[0] + '=' + tmp[1]);
            });
        if (!isexists) {
            result.unshift(parameterName + '=' + encodeURIComponent(val));
        }
        return result.join('&');
    }
    
    var methods = {
        init    : function(opts) {
            
                    return this.each(function() { //- do it for 'em all
    
                        var $this = $(this), //- get this variable for later
                            data = $this.data('PageSearch');
                        if (data) { return; } //- is seccondary call init if defined data
                        /*
                         * init
                         */
                        
                        if (!opts.target) return;
                        
                        data = {
                            url  : null,
                            target: opts.target,
                            request: null,
                            
                            getText: function() {},
                            text: '',
                        };
                        $this.data('PageSearch', data);
                        
                        var $form, $txt;
                        if ($this.get(0).nodeName == 'INPUT') {
                            $txt = $this;
                            var srchurl = $this.data('search-url');
                            if (srchurl) {
                                data.url = srchurl;
                            }
                            else {
                                $form = $this.closest('form');
                            }
                        }
                        else if ($this.get(0).nodeName == 'FORM') {
                            $form = $this;
                            $txt = $this.find('input').not('input[type="submit"]');
                        }
                        else {
                            return;
                        }
                        
                        if ($txt.length > 1) $txt = $txt.eq(0);
                        if ($txt.length != 1) return;
                        
                        if ($form) {
                            if ($form.length != 1) return;
                            data.url = $form.attr('action');
                        }
                        if (!data.url) return;
                        
                        data.getText = function() { return $txt.val(); };
                        data.text = data.getText();
                        
                        var timerKeypress = null;
                        $txt.keydown(function(e){
                            //if((e.keyCode >= 46 &&  e.keyCode <= 90) || e.keyCode == 8){
                            clearTimeout(timerKeypress);
                            timerKeypress = null;
                            
                            if (e.keyCode == 13) {
                                e.preventDefault();
                                $this.PageSearch('search');
                            }
                            else {
                                timerKeypress = setTimeout(function() {
                                        $this.PageSearch('search');
                                    },
                                    1000
                                );
                            }
                        });
                        
                        if (opts.search_on_init) {
                            var txt = findGetParameter('srch');
                            $txt.val(txt);
                            console.log('srch init', txt);
                            $this.PageSearch('search', true);
                            $(window).bind('popstate', function() {
                                txt = findGetParameter('srch');
                                console.log('srch popstate', txt);
                                $txt.val(txt);
                                $this.PageSearch('search', true);
                            });
                        }
                    });
                    
                },
                
        destroy : function( ) {
                    
                    return this.each(function(){
                        
                        var $this = $(this),
                            data = $this.data('PageSearch');
                        if (!data) return;
                        
                        $(window).unbind('.PageSearch');
                        $this.removeData('PageSearch');
                    });
                },
                
        search : function(noHistory) {
                    
                    return this.each(function(){
                        
                        var $this = $(this),
                            data = $this.data('PageSearch');
                        if (!data) return;
                        
                        if (!data.url) return;
                        
                        var txt = data.getText();
                        if (txt == data.text) return;
                        
                        if (data.request) {
                            
                            return;
                        }
                        
                        data.request = $.ajax({
                            url: data.url,
                            data: { srch: txt, is_modal: 2 /* content only template */ },
                            success: function(res) {
                                $(data.target).html(res);
                                data.text = txt;
                                if (!noHistory) {
                                    var q = findReplaceParameter('srch', txt);
                                    history.replaceState('', document.title, q === '' ? location.pathname : '?' + q);
                                }
                            },
                            complete: function() {
                                data.request = null;
                            },
                        });
                    });
                },
                
    };

    $.fn.PageSearch = function( method ) {
        if ( methods[method] ) {
            return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
        }
        else if ( typeof method === 'object' || ! method ) {
            return methods.init.apply( this, arguments );
        }
        else {
            $.error( 'Unknown method "' +  method + '" for jQuery.PageSearch' );
        }
    };

})(jQuery);