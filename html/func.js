/*
 * Form
 */

/*
function message(msg) {
    var myscroll = 50;
    var scroll = $(window).scrollTop();
    
    var $el = $('<div class="msg_inf"></div>');
    $el.hide();
    $('body').append($el);
    $el.html(msg);
    $el.click(function() { $(this).hide(); });
    
    var left = ($(window).width() - $el.width()) / 2;
    var z = 30;
    $el.css({ 'top' : '10px', 'left' : left, 'z-index': z });
    $el.delay(300).fadeIn('fast');
    
    var timeout = 3000;
    setTimeout(function(){
        $el.fadeOut('fast');
    }, timeout);
    setTimeout(function(){
        $el.remove();
    }, timeout+1000);
}
*/

$(function(){
    'use strict';
    /*
    $('form[data-hidden]').each(function() {
        var $this = $(this);
        var name = $this.attr('data-hidden');
        
        $this.hide();
        var $ref = $('<a href="#">'+name+' &gt;</a>');
        $this.before($ref);
        $ref.on('click', function(e) {
			e.preventDefault();
            $this.show('slow');
            $(this).slideUp();
        });
        
        $this.append('<input type="submit" value=" '+name+' ">');
        var $canc = $('<input type="button" value=" Отмена ">');
        $this.append($canc);
        $canc.on('click', function(e) {
			e.preventDefault();
            $this.slideUp('slow');
            $ref.show('slow');
        });
    });
    
    $('div[data-hidden]').each(function() {
        var $this = $(this);
        var name = $this.attr('data-hidden');
        
        $this.hide();
        var $ref = $('<a href="#">'+name+' &gt;</a>');
        $this.before($ref);
        $ref.on('click', function(e) {
			e.preventDefault();
            if ($this.is(':visible')) {
                $this.hide();
            }
            else {
                $this.show('slow');
                $(this).slideDown();
            }
        });
    });
    
    $('div[data-hidden-simple]').each(function() {
        var $this = $(this);
        var name = $this.attr('data-hidden-simple');
        
        $this.hide();
        var $ref = $('<a href="#">'+name+'</a>');
        $this.before($ref);
        $ref.on('click', function(e) {
			e.preventDefault();
            if ($this.is(':visible')) {
                $this.hide();
            }
            else {
                $this.show();
                $(this).slideDown();
            }
        });
    });
    */
    
        /*copyClipboard : function(str) {
                        let tmp   = document.createElement('INPUT'),
                        focus = document.activeElement;
                        tmp.value = str;
                        document.body.appendChild(tmp);
                        tmp.select();
                        document.execCommand('copy');
                        document.body.removeChild(tmp);
                        focus.focus();
                    },*/
        
    
    $('[data-copyfrom]').click(function(e) {
		e.preventDefault();
        var name = $(this).attr('data-copyfrom');
        $(name).select();
        document.execCommand('copy');
        message('Скопировано');
    });
    
    
    $('[data-hint]').each(function() {
        var hint = $(this).attr('data-hint');
        $(this).attr('alt', hint);
        $(this).attr('title', hint);
    });
    
    
    $('[data-hide-target]').click(function(e) {
        e.preventDefault();
        var target = $(this).attr('data-hide-target');
        $(target).toggle();
    });
    
    
    $('input#search-txt').PageSearch({ target: '#search-result' });
    $('[data-search-url]').PageSearch({ target: '#search-result' });

});

