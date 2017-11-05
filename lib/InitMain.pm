#!/usr/bin/perl

use strict;
use warnings;
no warnings 'once';

use utf8;

require "$::pathRoot/conf/defines.conf";
require "$::pathRoot/conf/rights.conf";
require "$::pathRoot/conf/text.conf";

use Func;
use Img;

__PACKAGE__->config(
    redefine        => $::pathRoot.'/conf/redefine.conf',
    
    view_default=> 'Main',
    schema      => 'DB',
    log_file    => "$::logPath/main.log",
    debug_file  => $::logDebug ? "$::logPath/main.log" : undef,
    pid_file    => "$::pidPath/main.fcgi.pid",
    bind        => '127.0.0.1:9004',
    
    controller_extended => 1,
    dispatcher  => {
        default                         => 'C::Misc::default',
        
        #$::disp{BlokList}               => 'C::Blok::list',
        $::disp{BlokShow}               => 'C::Blok::show',
        $::disp{BlokShowMy}             => 'C::Blok::show_my',
        $::disp{BlokFile}               => 'C::Blok::file',
        $::disp{BlokAdding}             => 'C::Blok::adding',
        $::disp{BlokAdd}                => 'C::Blok::set',
        $::disp{BlokSet}                => 'C::Blok::set',
        $::disp{BlokDel}                => 'C::Blok::del',
        
        $::disp{CommandList}            => 'C::Command::list',
        $::disp{CommandShow}            => 'C::Command::show',
        $::disp{CommandShowMy}          => 'C::Command::show_my',
        $::disp{CommandFile}            => 'C::Command::file',
        $::disp{CommandAdding}          => 'C::Command::adding',
        $::disp{CommandAdd}             => 'C::Command::set',
        $::disp{CommandSet}             => 'C::Command::set',
        $::disp{CommandLogo}            => 'C::Command::logo',
        $::disp{CommandDel}             => 'C::Command::del',
        $::disp{CommandHistory}         => 'C::Command::history',
        $::disp{CommandEventList}       => 'C::Command::event_list',

        $::disp{AusweisList}            => 'C::Ausweis::list',
        $::disp{AusweisShow}            => 'C::Ausweis::show',
        $::disp{AusweisFile}            => 'C::Ausweis::file',
        $::disp{AusweisAdding}          => 'C::Ausweis::adding',
        $::disp{AusweisAdd}             => 'C::Ausweis::set',
        $::disp{AusweisSet}             => 'C::Ausweis::set',
        $::disp{AusweisDel}             => 'C::Ausweis::del',
        $::disp{AusweisRegen}           => 'C::Ausweis::regen',
        $::disp{AusweisFindRepeat}      => 'C::Ausweis::find_repeat',
        
        $::disp{PrintList}              => 'C::Print::list',
        $::disp{PrintInfo}              => 'C::Print::info',
        $::disp{PrintFile}              => 'C::Print::file',
        $::disp{PrintAdd}               => 'C::Print::add',
        $::disp{PrintSet}               => 'C::Print::set',
        $::disp{PrintRegen}             => 'C::Print::regen',
        $::disp{PrintAusweisSearch}     => 'C::Print::ausweis_search',
        $::disp{PrintAusweisAdd}        => 'C::Print::ausweis_add',
        $::disp{PrintAusweisDel}        => 'C::Print::ausweis_del',
        
        $::disp{PreeditShowItem}        => 'C::Preedit::showitem',
        $::disp{PreeditFile}            => 'C::Preedit::file',
        $::disp{PreeditOp}              => 'C::Preedit::op',
        $::disp{PreeditHide}            => 'C::Preedit::hide',
        $::disp{PreeditCancel}          => 'C::Preedit::cancel',
        
        $::disp{EventList}              => 'C::Event::list',
        $::disp{EventShow}              => 'C::Event::show',
        $::disp{EventAdding}            => 'C::Event::adding',
        $::disp{EventAdd}               => 'C::Event::set',
        $::disp{EventSet}               => 'C::Event::set',
        $::disp{EventDel}               => 'C::Event::del',
        $::disp{EventMoneySet}          => 'C::Event::money_set',
        $::disp{EventMoneyListSet}      => 'C::Event::money_list_set',
        $::disp{EventAusweisCommit}     => 'C::Event::ausweis_commit',
        $::disp{EventAusweisDeCommit}   => 'C::Event::ausweis_decommit',
        $::disp{EventNecombatCommit}    => 'C::Event::necombat_commit',
        $::disp{EventNecombatDeCommit}  => 'C::Event::necombat_decommit',
    },
    
    return_custom => [qw/Operation/],
    
    plugins => [qw/ScriptTime
                    Session Authenticate Session::State Admin 
                    Admin::Edit 
                    Pager ListSort/],
    
    session     => { model => 'UserSession', auto_create => 0 },

    authenticate=> {
        model           => 'UserList',
        model_group     => 'UserGroup',
        link_group      => 'group',
        type            => 1,
        field_passnew   => 'pn',
        field_password2 => 'p2',
        
        #handler_login_ok        => \&C::Misc::login_ok,
        handler_login_er        => \&C::Misc::login_er,
        handler_password_change_ok => \&C::Misc::password_change_ok,
    },
    admin_edit  => {
        view_select             => 'Main',
        href_adminedit_redirect => 'admin/list',
        href_groupedit_redirect => 'admin/group_list',
        list_prefetch           => [qw/command group/],
    },
);

__PACKAGE__->run();

sub const_init {
    
    version     => '0.30',
    versionDate => '2017-10-29',
    
    db => {},
}



sub http_patt {
    my $self = shift;
    
    my $ver = $self->c('version');
    $ver = sprintf("%0.1f.%d", $1, $2 || 0) if $ver =~ /^(\d*\.\d)(\d*)$/;
    
    # Временно для корректной работы плагинов авторизации (потом надо заменить их на свои модули)
    # меняем точки в patt на подхеши
    my $patt = $self->patt;
    foreach my $key (keys %$patt) {
        my @key = split /\./, $key;
        next if @key < 2;
        my $val = delete $patt->{$key};
        my $keylast = pop @key;
        my $h = $patt;
        $h = ($h->{$_}||={}) foreach @key;
        #$val = $val->($self->view('Main')) if ref($val) eq 'CODE';
        $val = $$val if ref($val) eq 'SCALAR';
        $h->{$keylast} = $val;
    }
    
    return {
        IS_DEVEL        => $self->c('isDevel') ? 1 : 0,
        ip              => $ENV{REMOTE_ADDR},
        AUTOREFRESH     => 0,
        RUNCOUNT        => $self->{_run_count},
        href_base       => $self->href(),
        TIME            => scalar(localtime time),
        version         => $ver,
        verdate         => $self->c('versionDate'),
        #patt => $self->patt
    };
}

#### ------------------------------------
#### Работа с шаблонизатором
#### ------------------------------------
sub setbasetemplate {
    my $self = shift;
    my $view = shift;
    $view ||= $self->view_select('Main2'); # После переезда надо убрать ('Main2')
    
    if ($self->req->param_bool('is_modal')) {
        $view->basetemplate('base_modal');
    }
    elsif ($self->req->param_int('is_modal') == -1) {
        $view->withoutbasetemplate(1);
    }
}
sub notfound {
    my $self = shift;
    
    my $view = $self->view_select('Main2'); # После переезда надо убрать ('Main2')
    $view->template('notfound');
    $self->setbasetemplate($view);
    return (error => 100105) if $self->req->param_bool('is_ajax');
    return;
}

sub template { #  Выбор шаблона, так же проверяется способ отображения - модальное окно или страница целиком
    my ($self, $template, $block) = @_;
    
    my $view = $self->view_select('Main2'); # После переезда надо убрать ('Main2')
    $view->template($template);
    $view->block($block) if $block && ($self->req->param_int('is_modal') == 2);
    $self->setbasetemplate($view);
}

#### ------------------------------------
#### Возвращение статуса операции
#### ------------------------------------
sub return_operation {
    my ($self, %p) = @_;
    
    $self->disable_view();
    
    %p || return;
    
    my $ajax_redirect;
    if ($self->req->param_bool('is_ajax') || $self->req->param_bool('to_ajax')) {
        if (my $href = $p{redirect}) {
            $ajax_redirect = $href;
        }
        elsif (defined($href = $p{href})) {
            if (ref($href) eq 'ARRAY') {
                $ajax_redirect = $self->href(@$href);
            }
            elsif ($href eq '') {
                $ajax_redirect = $ENV{HTTP_REFERER};
            }
            else {
                $ajax_redirect = $self->href($href, @{ $p{args}||[] });
            }
        }
        elsif (defined(my $pref = $p{pref})) {
            if (ref($pref) eq 'ARRAY') {
                $ajax_redirect = $self->pref(@$pref);
            }
            else {
                $ajax_redirect = $self->pref($pref, @{ $p{args}||[] });
            }
            # Если указан mref (ссылка всплывающим окном)
            if (my $mref = $p{mref}) {
                if (ref($mref) eq 'ARRAY') {
                    $ajax_redirect .= '#m/' . $self->mref(@$mref);
                }
                else {
                    $ajax_redirect .= '#m/' . $self->mref($mref, @{ $p{margs}||[] });
                }
            }
            
        }
    }
    
    if ((my $ok = $p{ok})){# && (my $user = $self->user)) {
        if ($self->req->param_bool('is_ajax')) {
            my $message = $p{message} || $self->c(state => abs $ok);
    
            $self->return_json({ ok => 1, $message ? (message => $message) : (), $ajax_redirect ? (redirect => $ajax_redirect) : () });
            return;
        }
        elsif ($self->req->param_bool('to_ajax') && $ajax_redirect) {
            $self->redirect($ajax_redirect);
            return;
        }
        $self->cmd('Admin::state' => { state => abs $ok } );
    }
    elsif ((my $err = $p{error})){# && ($user = $self->user)) {
        if ($self->req->param_bool('is_ajax')) {
            my $message = $text::form_errors{$p{errno}||0} || $p{message} || $self->c(state => abs($err)*-1);
            my $field = $p{field} ? { map { ($_ => $text::form_errors{ $p{field}->{$_} }) } keys %{ $p{field} } } : undef;
            $self->return_json({ ok => 0, errno => abs($err), $message ? (message => $message) : (), $field ? (err_field => $field) : () });
            return;
        }
        $self->cmd('Admin::state' => { state => abs($err)*-1 } );
    }
    
    if (my $href = $p{redirect}) {
        $self->redirect($href);
    }
    
    if (defined(my $href = $p{href})) {
        if (ref($href) eq 'ARRAY') {
            $href = $self->href(@$href);
        }
        elsif ($href eq '') {
            $href = undef;
        }
        else {
            $href = $self->href($href, @{ $p{args}||[] });
        }
        
        $self->redirect($href);
    }
    
    if (my $mref = $p{mref}) {
        # Если указан mref (ссылка всплывающим окном), то без ajax используем ее как основную
        if (ref($mref) eq 'ARRAY') {
            $mref = $self->pref(@$mref);
        }
        else {
            $mref = $self->pref($mref, @{ $p{margs}||[] });
        }
        $self->redirect($mref);
    }
    elsif (defined(my $pref = $p{pref})) {
        if (ref($pref) eq 'ARRAY') {
            $pref = $self->pref(@$pref);
        }
        else {
            $pref = $self->pref($pref, @{ $p{args}||[] });
        }
        
        $self->redirect($pref);
    }
}












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
        date            => \&Func::dt_date,
        datetime        => \&Func::dt_datetime,
        IS_DEVEL        => $::isDevel ? 1 : 0,
        ip              => $ENV{REMOTE_ADDR},
        AUTOREFRESH     => 0,
        
        blk     => {
            href_list   => $self->href($::disp{BlokList}),
            href_adding => $self->href($::disp{BlokAdding}),
            list        => sub { C::Blok::_list($self); },
            hash        => sub { C::Blok::_hash($self); },
        },
        cmd     => {
            href_list   => $self->href($::disp{CommandList}),
            href_adding => $self->href($::disp{CommandAdding}),
            list        => sub { C::Command::_list($self); },
            hash        => sub { C::Command::_hash($self); },
        },
        aus     => {
            srch_num            => '',
            href_list           => $self->href($::disp{AusweisList}),
            href_adding         => $self->href($::disp{AusweisAdding}),
            href_find_repeat    => $self->href($::disp{AusweisFindRepeat}),
            allow_list          => 0,
        },
        prn     => {
            href_list   => $self->href($::disp{PrintList}),
            href_add    => $self->href($::disp{PrintAdd}),
        },
        preedit     => {
            href_showitem=>$self->href($::disp{PreeditShowItem}),
        },
        event     => {
            view        => $self->rights_exists($::rEventView) ? 1 : 0,
            href_list   => $self->href($::disp{EventList}),
            href_adding => $self->href($::disp{EventAdding}),
        },
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
    
    ############################
    
    my $d = $self->d;
    
    $d->{read_only} = $::db_Main{read_only} ? 1 : 0;
    if ($d->{read_only}) {
        $d->{read_only_date} = $::db_Main{read_only} =~ /\d+[\.\-]\d+[\.\-]\d+/ ?
            $::db_Main{read_only} : '';
    }
    
    if ($self->user && $self->user->{id}) {
        ($d->{mycmd}) = map { C::Command::_item($self, $_) }
            $self->model('Command')->search({ id => $self->user->{cmdid} }, { prefetch => 'blok' })
            if $self->user->{cmdid};
        $d->{mycmd} ||= { id => 0, blkid => 0 };
        $self->user->{cmdid} = $d->{mycmd}->{id};
        $self->user->{blkid} = $d->{mycmd}->{blkid};
        
        $d->{aus}->{allow_list} = $self->rights_exists($::rAusweisList);
    }
    
    if ($d->{event}->{view}) {
        $d->{event}->{open_list} = sub {
            $d->{event}->{_open_list} ||= [
                map { 
                    my $ev = C::Event::_item($self, $_);
                    $ev->{count_ausweis} = sub {
                        if (!defined($ev->{_count_ausweis})) {
                            $ev->{_count_ausweis} = $self->model('EventAusweis')->count({ evid => $ev->{id} });
                            $ev->{_count_ausweis} ||= 0;
                        }
                        $ev->{_count_ausweis};
                    };
                    $ev->{count_necombat} = sub {
                        if (!defined($ev->{_count_necombat})) {
                            $ev->{_count_necombat} = $self->model('EventNecombat')->count({ evid => $ev->{id} });
                            $ev->{_count_necombat} ||= 0;
                        }
                        $ev->{_count_necombat};
                    };
                    $ev;
                }
                $self->model('Event')->search({
                    status  => 'O',
                }, {
                    order_by => [qw/date id/],
                })
            ];
        };
    }
    
    ############################
    
    # Меню администратора
    my $i = 0;
    $self->d->{menu} = [
        map {
            my ($title, @m) = @$_;
            my ($last_is_item, @menu);
            foreach my $item (@m) {
                my $is_item = $item && $item->[0];
                if ($is_item && defined($item->[2])) {
                    my $r = ref($item->[2]) eq 'CODE' ? $item->[2]->($self) : $item->[2];
                    $r || next;
                }
                if ($is_item) {
                    push @menu, {
                        is_item => 1,
                        text    => $item->[0],
                        href    => ref($item->[1]) eq 'CODE' ? $item->[1]->($self) : $item->[1]
                    };
                    $last_is_item = 1;
                }
                elsif ($last_is_item) {
                    push @menu, { is_item => 0 };
                    $last_is_item = 0;
                }
            }
            pop @menu if @menu && !$menu[@menu-1]->{is_item};
            { i => ++$i, title => $title, list => \@menu };
        }
        @rights::AdminMenu
    ];
    
#    # Главная страница
#    if (!$self->d->{denied} &&
#        (!$ENV{PATH_INFO} || ($ENV{PATH_INFO} =~ /^\/$/))) {
#        if ($self->rights_exists($::rAusweisList)) {
#            $self->forward($::disp{AusweisList});
#        }
#        elsif ($self->rights_check($::rCommandInfo, $::rMy)) {
#            $self->forward(sprintf($::disp{CommandShowMy}, 'info'));
#        }
#    }
    
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

sub can_edit {
    my $self = shift;
    
    if ($self->d->{read_only}) {
        $self->state(-000107, '');
        return;
    }
    
    1;
}


1;
