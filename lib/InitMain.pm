#!/usr/bin/perl

use strict;
#use warnings;
use FindBin::Real qw(Bin);
$::pathRoot = Bin.'/..';

require "$::pathRoot/conf/defines.conf";
require "$::pathRoot/conf/rights.conf";
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
    
    session     => { model => 'UserSession', auto_create => 0 },

    authenticate=> {
        model   => 'UserList',
        type    => 1,
        field_passnew   => 'pn',
        field_password2 => 'p2',
        link_group => 'group',
        
        #handler_login_ok        => \&C::Misc::login_ok,
        handler_login_er        => \&C::Misc::login_er,
        handler_password_change_ok => \&C::Misc::password_change_ok,
    },
    admin_edit  => {
        view_select             => 'Main',
        href_adminedit_redirect => 'admin/list',
        href_groupedit_redirect => 'admin/group_list',
    },
);

__PACKAGE__->run();

sub http_accept {
    my $self = shift;

    # Глобальный доступ
    if (!$self->rights_exists($::rMain)) {
        if ($ENV{PATH_INFO} && ($ENV{PATH_INFO} !~ /login$/)) {
            $self->patt->{redirect} = "http://$ENV{HTTP_HOST}$ENV{REQUEST_URI}";
            $ENV{PATH_INFO} = '';
        } elsif ($ENV{PATH_INFO} =~ /login$/) {
            $self->patt->{redirect} = $self->req->param_str('redirect');
        }
        $self->d->{denied} = 1;
        $self->patt->{redirect} = $self->ToHtml($self->d->{redirect});
    }
    
    $self->{_run_count} ||= 0;
    $self->{_run_count} ++;
    
    $self->data(
        IS_DEVEL=> $::isDevel ? 1 : 0,
        ip      => $ENV{REMOTE_ADDR},
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
        
        PRE     => sub { 
            use Data::Dumper; 
            join ("\n\n", Dumper($self->patt, $self->d, \%ENV, 
             { config => $self->config, config_static => $self->{_config_static}, config_mysql => $self->{_config_mysql}  }, )) 
        },
    );
}


sub rights_denied {
    my ($self, $RNum) = @_;
    $self->state(-000102, '');
}

sub ParamParse {
    my ($self, %args) = @_;
    
    my $ret = $self->SUPER::ParamParse(%args) && return 1;
    
    foreach my $err (@{ $self->d->{form_error} }) {
        my ($errno, $param, $index) = @$err;
        $err = {
            num         => $errno,
            param       => $text::params_name{$param} || $param,
            str         => $text::form_errors{$errno} || sprintf($text::form_errors{unknown}, $errno),
            index       => $index+1,
        };
    }
    
    foreach my $param (keys %{ $self->d->{form_check} }) {
        my $index = 0;
        foreach my $errno (@{ $self->d->{form_check}->{$param} }) {
            $errno = {
                num     => $errno,
                param   => $text::params_name{$param} || $param,
                str     => $text::form_errors{$errno} || sprintf($text::form_errors{unknown}, $errno),
                index   => ++$index,
            } if $errno;
        }
    }
    
    return $ret;
}


1;
