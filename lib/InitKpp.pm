#!/usr/bin/perl

use strict;
use warnings;
no warnings 'once';

use utf8;

require "$::pathRoot/conf/defines.conf";

__PACKAGE__->config(
    redefine        => $::pathRoot.'/conf/redefine.conf',
    
    schema      => 'DB',
    log_file    => "$::logPath/kpp.log",
    debug_file  => $::logDebug ? "$::logPath/kpp.log" : undef,
    pid_file    => "$::pidPath/kpp.fcgi.pid",
    bind        => '127.0.0.1:9005',
    
    controller_extended => 'CKpp',
    dispatcher  => { default => sub { shift->default() } },
);

__PACKAGE__->run();

sub const_init {
    
    db => {},
}


sub http_accept {
    my ($self, $path) = @_;
    
    $self->{_run_count} ||= 0;
    $self->{_run_count} ++;
    
    CKpp::Auth::init($self, $path)
        || return $self->disable_dispatcher;
}

# По умолчанию return_json ожидает либо ссылку на хеш, либо ссылку на массив,
# мы принудительно делаем формат - просто хеш и заворачиваем его в ссылку
sub return_json { shift->SUPER::return_json({ @_ }); }

sub default { # Возврат  Страница не найдена
    my $self = shift;
    
    return $self->return_json( error => 404 );
}


sub nfound { # Возврат ошибки прав доступа для обработчиков с аттрибутом ReturnOperation
    my $self = shift;
    
    return ( error => 105 );
}

sub cantedit { # Возврат ошибки прав доступа для обработчиков с аттрибутом ReturnOperation
    my $self = shift;
    
    return ( error => 107 );
}

#### ------------------------------------
####    Объекты
#### ------------------------------------
sub obj_cmd {
    my $self = shift;
    
    $self->object_by_model(
        'Command',
    )
}

1;
