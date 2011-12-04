#!/usr/bin/perl

use strict;
#use warnings;
#$::pathRoot ||= '/home/ausweis';

require "$::pathRoot/conf/defines.conf";
require "$::pathRoot/conf/rights.conf";
require "$::pathRoot/conf/text.conf";

use Func;
use Img;

__PACKAGE__->config(
    view_default=> 'Main',
    schema      => 'DB',
    log_file    => "$::logPath/main.log",
    debug_file  => $::logDebug ? "$::logPath/main.log" : undef,
    
    dispatcher  => {
        default                         => 'C::Misc::default',
        
        $::disp{BlokList}               => 'C::Blok::list',
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
        $::disp{CommandHistoryHide}     => 'C::Command::history_hide',

        $::disp{AusweisList}            => 'C::Ausweis::list',
        $::disp{AusweisShow}            => 'C::Ausweis::show',
        $::disp{AusweisFile}            => 'C::Ausweis::file',
        $::disp{AusweisAdding}          => 'C::Ausweis::adding',
        $::disp{AusweisAdd}             => 'C::Ausweis::set',
        $::disp{AusweisSet}             => 'C::Ausweis::set',
        $::disp{AusweisDel}             => 'C::Ausweis::del',
        $::disp{AusweisRegen}           => 'C::Ausweis::regen',
        
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
            srch_num    => '',
            href_list   => $self->href($::disp{AusweisList}),
            href_adding => $self->href($::disp{AusweisAdding}),
            allow_list  => 0,
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


1;
