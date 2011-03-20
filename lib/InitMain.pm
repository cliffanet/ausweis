#!/usr/bin/perl

use strict;
#use warnings;
use FindBin::Real qw(Bin);
$::pathRoot = Bin.'/..';

require "$::pathRoot/conf/defines.conf";
require "$::pathRoot/conf/text.conf";

__PACKAGE__->config(
    view_default=> 'Main',
    schema      => 'DB',
    log_file    => "$::logPath/main.log",
    debug_file  => $::logDebug ? "$::logPath/main.log" : undef,
    
    dispatcher  => {
        default                         => 'C::Misc::default',
        
        $::disp{AusweisList}            => 'C::Ausweis::list',
    },
    
    plugins => [qw/ScriptTime
                    Session Authenticate Session::State Admin 
                    Admin::Edit 
                    Pager ListSort/],
    
    session     => { model => 'UserSession', auto_create => 1 },
    authenticate=> {
        model   => 'UserList',
        type    => 2,
    },
);

__PACKAGE__->run();

sub http_accept {
    my $self = shift;
    
    $self->{_run_count} ||= 0;
    $self->{_run_count} ++;
    
    $self->data(
        IS_DEVEL=> $::isDevel ? 1 : 0,
        ip      => $ENV{REMOTE_ADDR},
        #ip      => '10.191.0.41',
        #ip      => '94.228.170.207',
    );
    
    $self->patt(
        TITLE   => sprintf("%s (ver. %s)", $text::titles{default}, $::version),
        CONTENT => '',
        
        ip      => $ENV{REMOTE_ADDR},
        
        RUNCOUNT=> $self->{_run_count},
        href_base=>$self->href(),
        TIME    => scalar(localtime time),
        VERSION => sprintf("%0.2f", $::VERSION),
        version => $::version,
    );
    
}

1;
