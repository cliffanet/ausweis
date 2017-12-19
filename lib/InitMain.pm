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
use Encode '_utf8_off';

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
    },
    
    return_custom => [qw/Operation/],
);

=pod

        #$::disp{AusweisFindRepeat}      => 'C::Ausweis::find_repeat',
        
        #$::disp{PrintList}              => 'C::Print::list',
        #$::disp{PrintInfo}              => 'C::Print::info',
        #$::disp{PrintFile}              => 'C::Print::file',
        #$::disp{PrintAdd}               => 'C::Print::add',
        #$::disp{PrintSet}               => 'C::Print::set',
        #$::disp{PrintRegen}             => 'C::Print::regen',
        #$::disp{PrintAusweisSearch}     => 'C::Print::ausweis_search',
        #$::disp{PrintAusweisAdd}        => 'C::Print::ausweis_add',
        #$::disp{PrintAusweisDel}        => 'C::Print::ausweis_del',
        
        #$::disp{EventList}              => 'C::Event::list',
        #$::disp{EventShow}              => 'C::Event::show',
        #$::disp{EventAdding}            => 'C::Event::adding',
        #$::disp{EventAdd}               => 'C::Event::set',
        #$::disp{EventSet}               => 'C::Event::set',
        #$::disp{EventDel}               => 'C::Event::del',
        #$::disp{EventMoneySet}          => 'C::Event::money_set',
        #$::disp{EventMoneyListSet}      => 'C::Event::money_list_set',
        #$::disp{EventAusweisCommit}     => 'C::Event::ausweis_commit',
        #$::disp{EventAusweisDeCommit}   => 'C::Event::ausweis_decommit',
        #$::disp{EventNecombatCommit}    => 'C::Event::necombat_commit',
        #$::disp{EventNecombatDeCommit}  => 'C::Event::necombat_decommit',
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
=cut

__PACKAGE__->run();

sub const_init {
    
    version     => '0.30',
    versionDate => '2017-10-29',
    
    db => {},
    
    userError => {
        1   => 'Неверно указано имя пользователя или пароль',
        2   => 'Ошибка сохранения сессии в БД',
        3   => 'Ошибка изменения сессии в БД',
        4   => 'Логин не может быть пустым',
        5   => 'Неизвестная ошибка авторизации',
        6   => 'Недостаточно прав для выполнения операции',
        7   => 'Недостаточно прав для отображения информации',
        8   => 'Элемента не существует',
        11  => 'Сессия не найдена',
        12  => 'Изменился IP сессии',
        13  => 'Произведен вход из другого места',
        14  => 'Аккаунт заблокирован',
        15  => 'Превышен интервал бездействия',
        16  => 'Закончилось максимальное время сессии',
    },
    
    rtypes    => [
        [Read       => 'r'  => "Чтение"],
        [Write      => 'w'  => "Изменение"],
        [Yes        => 'y'  => "Да"],
        [My         => 'm'  => "Только свои"],
        [Advanced   => 'a'  => "Расширенный"],
        [All        => 'z'  => "Все"],
        [Add        => 'c'  => "Добавление"],
        [No         => '-'  => "Нет"],
        [Group      => 'g'  => "Как у группы"],
    ],
    
    rights => [
        "Доступ к системе",
        [Main               => 1    => "Глобальный доступ"                  => qw/Yes/],
        [Admins             => 2    => "Пользователи"                       => qw/Read Write/],
        [Msg                => 3    => "Сообщения"                          => qw/Read Advanced/],
        'База аусвайсов',
        [BlokList           => 11   => "Блоки: список"                      => qw/Read/],
        [BlokInfo           => 12   => "Блоки: информация"                  => qw/My All/],
        [BlokEdit           => 13   => "Блоки: редактирование"              => qw/My All/],
        [CommandList        => 21   => "Команды: список"                    => qw/Read/],
        [CommandInfo        => 22   => "Команды: информация"                => qw/My All/],
        [CommandEdit        => 23   => "Команды: редактирование"            => qw/My All/],
        [CommandLogo        => 24   => "Команды: загрузка логотипа"         => qw/My All/],
        [AusweisList        => 31   => "Аусвайсы: список"                   => qw/Read/],
        [AusweisInfo        => 32   => "Аусвайсы: информация"               => qw/My All/],
        [AusweisEdit        => 33   => "Аусвайсы: редактирование"           => qw/My All/],
        [AusweisPreEdit     => 34   => "Аусвайсы: запрос на изменение"      => qw/My All/],
        #[AusweisFindRepeat  => 35   => "Аусвайсы: поиск повторов"           => qw/Yes/],
        'Общее управление',
        #[Print              => 40   => "Печать"                             => qw/Read Write/],
        #[PrintAusweis       => 41   => "Печать: работа с аусвайсами"        => qw/My All/],
        [Preedit            => 50   => "Модерация изменений в базе"         => qw/Yes/],
        [PreeditCancel      => 51   => "Модерация изменений : отмена заявки"=> qw/My All/],
        [Event              => 45   => "Мероприятия"                        => qw/Read Write Advanced/],
        #[EventView          => 46   => "Мероприятия: особое отображение"    => qw/Yes/],
        #[EventCommit        => 47   => "Мероприятия: регистрация на КПП"    => qw/Yes Advanced/],
    ],
    
    menu    => [
        "Администрирование",
        ["Аккаунты"         =>  admin_read      => 'admin'],
        #'Администрирование',
        #[ 'Аккаунты',           sub { shift->d->{admin}->{href_list} },
        #                        sub { $_[0]->rights_exists($rAdmins) } ],
        #[ 'Группы',             sub { shift->d->{admin_group}->{href_list} },
        #                        sub { $_[0]->rights_exists($rAdmins) } ],
        undef,
        #[ 'Печать',             sub { shift->href($::disp{PrintList}) },
        #                        sub { $_[0]->rights_exists($rPrint) } ],
        [ 'Модерация',      => preedit_first    => 'preedit/first' ],
        #[ 'Поиск повторов',     sub { shift->href($::disp{AusweisFindRepeat}) },
        #                        sub { $_[0]->rights_exists($rAusweisFindRepeat) } ],
        [ 'Мероприятия',    => event_read       => 'event/list' ],
        'Аусвайсы',
        [ 'Блоки'           => blok_list        => 'blok/list' ],
        [ 'Команды'         => command_list     => 'command/list' ],
        [ 'Аусвайсы'        => ausweis_list     => 'ausweis/list' ],
        [ 'Моя команда'     => command_info     => 'command/my' ],
        [ 'Сообщения'       => msg_read         => 'msg' => \&msg_count ],
        undef,
        [ 'Добавить команду'=> command_edit_all => 'command/adding' ],
    ],
    
    opstate => {
        000101      => 'Ошибка ввода данных',
        000102      => 'Доступ к фунции запрещен',
        000103      => 'Ни одно из полей не изменено',
        000104      => 'Ошибка сохранения данных в БД',
        000105      => 'Запись отсутствует в БД',
        000106      => 'Не сделано ни одного изменения в базе',
        000107      => 'База находится в режиме "только для чтения"',
        
        10100       => 'Вход в систему',
        10101       => 'Вход в систему: системная(внутренняя) ошибка',
        10102       => 'Вход в систему: необходимо указать имя пользователя',
        10103       => 'Вход в систему: неверные имя пользователя или пароль',
        10200       => 'Выход',
        10202       => 'Выход невозможен без предварительной авторизации',
        10300       => 'Смена пароля',
        10301       => 'Текущий пароль указан неверно',
        10302       => 'Не указан новый пароль',
        10303       => 'Новый пароль не подтвержден',
        11000       => 'Изменение вида деятельности',
        11101       => 'Обнаружена попытка доступа к сессии с другого IP',
        11102       => 'Ошибочная попытка входа под Вашим аккаунтом из другого места',
        11103       => 'Был произведен вход под этим же аккаунтом из другого места',
            
        20100       => 'Добавление пользователя',
        20101       => 'Ошибка подтверждения пароля',
        20200       => 'Добавлние группы',
        20300       => 'Изменение пользователя',
        20301       => 'Ошибка подтверждения пароля',
        20400       => 'Изменение группы',
        20500       => 'Удаление пользователя',
        20600       => 'Удаление группы',
        
        # аусвайсы
        990100      => 'Добавление аусвайса',
        990200      => 'Изменение аусвайса',
        990400      => 'Запуск пересборки аусвайса',
            
        # команды
        980100      => 'Добавление команды',
        980200      => 'Изменение команды',
        980300      => 'Удаление команды',
        980301      => 'Удаление невозможно, пока к команде прикреплены аусвайсы',
        
        # блоки
        970100      => 'Добавление блока',
        970200      => 'Изменение блока',
        970300      => 'Удаление блока',
        
        # печать
        960100      => 'Создание партии на печать',
        960200      => 'Изменение печати',
        960400      => 'Запуск пересборки печати',
        960401      => 'Пересборка невозможна при этом статусе партии',
        960500      => 'Добавление аусвайсов в печать',
        960600      => 'Удаление аусвайсов из печати',
        960501      => 'Добавление/удаление невозможно в этой партии',
        
        # Премодерация
        950100      => 'Модерация изменений в базе',
        950400      => 'Скрытие логов премодерации',
        950500      => 'Отмена заявки на изменение',
        950501      => 'Заявка на изменение уже отмедерирована или отменена',
        
        # мероприятия
        940100      => 'Добавление мероприятия',
        940200      => 'Изменение мероприятия',
        940300      => 'Удаление мероприятия',
        940301      => 'Удаление возможно только при отсутствии начатого процессинга',
        940400      => 'Изменение взноса на мероприятие',
        940500      => 'Регистрация участника на мероприятии',
        940501      => 'Участник уже зарегистрирован',
        940502      => 'Не могу определить сумму взноса',
        940503      => 'Нет заранее сданного взноса',
        940600      => 'Отмена прохода через КПП',
        940700      => 'Регистрация некомбатанта',
        940800      => 'Отмена прохода некомбатанта',
        
        # оповещения
        930100      => 'Изменение подписки на сообщения',
        
        # 
        900101      => 'Ошибка временной директории',
        900102      => 'Ошибка загрузки файла',
    },
    

    ####    Формы ввода данных
    form_errors => {
        unknown     => 'Неизвестная ошибка (%d)',
        1           => 'Обязательное для заполнения поле',
        2           => 'Введенные данные не соответствуют формату поля',
        3           => 'Значение введено неверно',
        4           => 'Требуется подтверждение',
        5           => 'Выбран несуществующий элемент',
        6           => 'Значение уже занято',
        7           => 'Значение должно быть строго положительное',
        
        11          => 'Несуществующий блок',
        12          => 'Несуществующая команда',
        13          => 'Команда с таким названием уже существует',
        14          => 'Такой аккаунт уже существует',
        15          => 'Ошибка определения группы аккаунта',
        21          => 'Аусвайс с таким ником уже существует в команде',
        22          => 'Заблокированный аусвайс с таким ником уже существует в команде. Чтобы заблокировать еще один - смените ник',
        23          => 'Аусвайс с таким фио уже существует в команде',
    },

    # Группа пользователей "Командиры команд"
    command_gid => 0,
    
    msg => {
        auspreeditok    => 'Успешно промодерирован аусвайс %s - %s',
        auspreediterr   => 'Отклонены изменения для аусвайса %s - %s: %s',
    },
}

sub http_after_init {
    my $self = shift;
    
    my %num = ();
    if (my $rights = $self->c('rights')) {
        foreach my $r (@$rights) {
            ref($r) || next;
            my ($name, $num, $title, @variant) = @$r;
            $num{$name} = $num;
            #eval "\$\::r$name = $num;";
        }
    }
    my %val = ();
    if (my $rtypes = $self->c('rtypes')) {
        foreach my $r (@$rtypes) {
            ref($r) || next;
            my ($name, $val, $title) = @$r;
            $val{$name} = $val;
            #eval "\$\::$name = $val;";
        }
    }
    
    use Clib::Rights;
    $self->{rcheck} = {
        global          => sub { rights_Check($_[0],    $num{Main},     $val{Yes}); },
        
        admin_read      => sub { rights_Exists($_[0],   $num{Admins}); },
        admin_write     => sub { rights_Check($_[0],    $num{Admins},   $val{Write}); },
        
        msg_read       => sub { rights_Exists($_[0],   $num{Msg}); },
        msg_cfg        => sub { rights_Check($_[0],    $num{Msg},   $val{Advanced}); },
        
        blok_list       => sub { rights_Exists($_[0],   $num{BlokList}); },
        blok_info       => sub { rights_Exists($_[0],   $num{BlokInfo}); },
        blok_info_all   => sub { rights_Check($_[0],    $num{BlokInfo}, $val{All}); },
        blok_edit       => sub { rights_Exists($_[0],   $num{BlokEdit}); },
        blok_edit_all   => sub { rights_Check($_[0],    $num{BlokEdit}, $val{All}); },
        blok_file       => sub { rights_Exists($_[0],   $num{BlokInfo}) ||
                                 rights_Exists($_[0],   $num{CommandInfo}); },
        blok_file_all   => sub { rights_Check($_[0],    $num{BlokInfo}, $val{All}) ||
                                 rights_Check($_[0],    $num{CommandInfo}, $val{All}); },
        
        command_list    => sub { rights_Exists($_[0],   $num{CommandList}); },
        command_info    => sub { rights_Exists($_[0],   $num{CommandInfo}); },
        command_info_all=> sub { rights_Check($_[0],    $num{CommandInfo}, $val{All}); },
        command_edit    => sub { rights_Exists($_[0],   $num{CommandEdit}); },
        command_edit_all=> sub { rights_Check($_[0],    $num{CommandEdit}, $val{All}); },
        command_logo    => sub { rights_Exists($_[0],   $num{CommandLogo}); },
        command_logo_all=> sub { rights_Check($_[0],    $num{CommandLogo}, $val{All}); },
        command_file    => sub { rights_Exists($_[0],   $num{CommandInfo}) ||
                                 rights_Exists($_[0],   $num{CommandInfo}); },
        command_file_all=> sub { rights_Check($_[0],    $num{CommandInfo}, $val{All}) ||
                                 rights_Check($_[0],    $num{AusweisInfo}, $val{All}); },
        
        ausweis_list    => sub { rights_Exists($_[0],   $num{AusweisList}); },
        ausweis_info    => sub { rights_Exists($_[0],   $num{AusweisInfo}); },
        ausweis_info_all=> sub { rights_Check($_[0],    $num{AusweisInfo}, $val{All}); },
        ausweis_edit    => sub { rights_Exists($_[0],   $num{AusweisEdit}) ||
                                 rights_Exists($_[0],   $num{AusweisPreEdit}); },
        ausweis_edit_all=> sub { rights_Check($_[0],    $num{AusweisEdit}, $val{All}) ||
                                 rights_Check($_[0],    $num{AusweisPreEdit}, $val{All}); },
        ausweis_pree    => sub {!rights_Exists($_[0],   $num{AusweisEdit}) &&
                                 rights_Exists($_[0],   $num{AusweisPreEdit}); },
        ausweis_pree_all=> sub {!rights_Check($_[0],    $num{AusweisEdit}, $val{All}) &&
                                 rights_Check($_[0],    $num{AusweisPreEdit}, $val{All}); },
        ausweis_file    => sub { rights_Exists($_[0],   $num{AusweisInfo}); },
        ausweis_file_all=> sub { rights_Check($_[0],    $num{AusweisInfo}, $val{All}); },
        
        preedit_first   => sub { rights_Exists($_[0],   $num{Preedit}); },
        preedit_op      => sub { rights_Exists($_[0],   $num{Preedit}); },
        preedit_hide    => sub { rights_Exists($_[0],   $num{CommandInfo}); },
        preedit_cancel  => sub { rights_Exists($_[0],   $num{PreeditCancel}); },
        preedit_cancel_all=>sub{ rights_Check($_[0],    $num{PreeditCancel}, $val{All}); },
        
        event_read      => sub { rights_Exists($_[0],   $num{Event}); },
        event_edit      => sub { rights_Check($_[0],    $num{Event}, $val{Write}, $val{Advanced}); },
        event_advanced  => sub { rights_Check($_[0],    $num{Event}, $val{Advanced}); },
    };
}


sub user { @_ > 1 ? $_[0]->data(user => $_[1]) : $_[0]->data->{user} }
sub admin { @_ > 1 ? $_[0]->data(admin => $_[1]) : $_[0]->data->{admin} }


sub http_accept {
    my ($self, $path) = @_;
    
    $self->{_run_count} ||= 0;
    $self->{_run_count} ++;
    
    C::Auth::init($self, $path)
        || return $self->disable_dispatcher;
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
    
    my %u = ();
    my $u = $self->user;
    if ($u && $u->{login}) {
        $u{ok} = 1;
        $u{denied} = $self->rcheck('global') ? 0 : 1; 
        $u{login} = $u->{login};
        $u{group} = $u->{group} && $u->{group}->{id} ? $u->{group}->{name} : '';
    }
    else {
        $u{ok} = 0;
        $u{error} = $self->d->{auth_error} if $self->d->{auth_error};
    }
    
    my $mt = { list => [] };
    my @menu =
        grep { $_->{is_item} || @{ $_->{list} } }
        map {
            if (ref($_) eq 'ARRAY') {
                my ($title, $rcheck, $pref, @args) = @$_;
                my $fadd = ref($args[0]) eq 'CODE' ? shift(@args) : undef;
                my @m;
                if ($self->rcheck($rcheck)) {
                    if ($fadd) {
                        my $fres = $fadd->($self);
                        $title .= sprintf(' (%s)', $fres) if $fres;
                    }
                    @m = { is_item => 1, title => $title, href => $self->pref($pref, @args) };
                }
                push @{ $mt->{list} }, @m;
                @m;
            }
            elsif ($_) {
                $mt = { is_title => 1, title => $_, list => [] };
            }
            else {
                $mt = { is_splitter => 1, list => [] };
            }
        }
        @{ $self->c('menu') || [] };
    
    my $state = 0;
    if (my $st = $self->session_state) {
        $state = {
            code    => $st,
            codeabs => abs($st),
            msg     => $self->c(opstate => abs $st),
        };
        $self->session_state(0);
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
        user            => \%u,
        menu            => \@menu,
        state           => $state,
        allow_ausweis_list => $self->rcheck('ausweis_list'),
        numidnick       => '',
    };
}

#### ------------------------------------
####    Работа с шаблонизатором
#### ------------------------------------
sub setbasetemplate {
    my $self = shift;
    my $view = shift;
    $view ||= $self->view_select;
    
    if ($self->req->param_bool('is_modal')) {
        $view->basetemplate('base_modal');
    }
    elsif ($self->req->param_int('is_modal') == -1) {
        $view->withoutbasetemplate(1);
    }
}
sub notfound {
    my $self = shift;
    
    my $view = $self->view_select;
    $view->template('notfound');
    $self->setbasetemplate($view);
    return (error => 000105) if $self->req->param_bool('is_ajax');
    return;
}

sub nfound { # Возврат ошибки прав доступа для обработчиков с аттрибутом ReturnOperation
    my $self = shift;
    
    if ($self->req->param_bool('is_ajax')) {
        $self->json({ error => $self->c(opstate => 000105) });
        return;
    }
    
    return ( error => 000105, href => '' );
}

sub cantedit { # Возврат ошибки прав доступа для обработчиков с аттрибутом ReturnOperation
    my $self = shift;
    
    if ($self->req->param_bool('is_ajax')) {
        $self->json({ error => $self->c(opstate => 000107) });
        return;
    }
    
    return ( error => 000107, href => '' );
}

sub template { #  Выбор шаблона, так же проверяется способ отображения - модальное окно или страница целиком
    my ($self, $template, $block) = @_;
    
    my $view = $self->view_select;
    $view->template($template);
    $view->block($block) if $block && ($self->req->param_int('is_modal') == 2);
    $self->setbasetemplate($view);
}

sub excel {
    my ($self, $tmpl, $fname, %patt) = @_;
    
    $self->view_select('Excel', $tmpl, $fname);
    my $xls = ($self->d->{excel} = {});
    $xls->{$_} = $patt{$_} foreach keys %patt;
    return %$xls;
}

#### ------------------------------------
####    Возвращение статуса операции
#### ------------------------------------
sub return_operation {
    my ($self, %p) = @_;
    
    $self->disable_view() if !delete($p{view});
    
    %p || return;
    
    if (my $errlog = $p{errlog}) {
        $self->error(ref($errlog) eq 'ARRAY' ? @$errlog : $errlog);
    }
    
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
    
    my $formpar = '';
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
        $self->session_state(abs $ok);
    }
    elsif ((my $err = $p{error})){# && ($user = $self->user)) {
        if ($self->req->param_bool('is_ajax')) {
            my $message = $text::form_errors{$p{errno}||0} || $p{message} || $self->c(state => abs($err)*-1);
            my $field = $p{field} ? { map { ($_ => $text::form_errors{ $p{field}->{$_} }) } keys %{ $p{field} } } : undef;
            $self->return_json({ ok => 0, errno => abs($err), $message ? (message => $message) : (), $field ? (err_field => $field) : () });
            return;
        }
        $self->session_state(abs($err)*-1);
        
        # Ошибка после формы редактирования
        my $form = $p{upar};
        if ($form && %$form) {
            # Старая форма редактирования через ParamParse
            my @form =
                map {
                    my $val = $form->{$_};
                    Encode::_utf8_off($val);
                    $_ . '=' . Clib::Mould->ToUrl($val)
                }
                grep { defined($form->{$_}) && ($form->{$_} ne '') }
                grep { /^[A-Za-z\_\d]+$/ }
                keys %$form;
            use Data::Dumper;
            $self->debug(Dumper \@form);
            if ($form = $self->d->{form_check}) {
                my @f =
                    map { $_ .  '-' . $form->{$_}->[0]->{num} }
                    grep { $form->{$_} && $form->{$_}->[0] }
                    keys %$form;
                if (@f) {
                    push @form, 'field_error=' . join(',', @f);
                }
            }
            $formpar = join '&', @form;
        }
        elsif ($p{fpar}) {
            # Новая форма редактирования, где мы параметры парсим прям в методе и ошибки формируем там же
            my @form =
                map { $_ . '=' . Clib::Mould->ToUrl($self->req->param($_)) }
                grep { defined $self->req->param($_) }
                @{ $p{fpar} };
            if ($p{ferr}) {
                my @f =
                    map { $_ .  '-' . $p{ferr}->{$_} }
                    grep { $p{ferr}->{$_} }
                    @{ $p{fpar} };
                if (@f) {
                    push @form, 'field_error=' . join(',', @f);
                }
            }
            $formpar = join '&', @form;
        }
    }
    
    if (my $href = $p{redirect}) {
        $href .= '?' . $formpar if $formpar;
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
        
        $href .= '?' . $formpar if $formpar;
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
        
        $pref .= '?' . $formpar if $formpar;
        $self->redirect($pref);
    }
}

#### ------------------------------------
####    Права
#### ------------------------------------
sub rcheck {
    my $self = shift;
    
    my $admin = $self->admin || return;
    my $rights = $admin->{rights} || return;
    $_[0] || return;
    my $rc = $self->{rcheck}->{ $_[0] } || return;
    
    return $rc->($rights);
}

sub view_rcheck { # Проверка прав в обработчиках отображения информации
    my ($self, $r) = @_;
    
    return 1 if $self->rcheck($r);
    
    $self->template('rdenied');
    
    return;
}

sub rdenied { # Возврат ошибки прав доступа для обработчиков с аттрибутом ReturnOperation
    my $self = shift;
    
    if ($self->req->param_bool('is_ajax')) {
        $self->json({ error => $self->c(opstate => 000102) });
        return;
    }
    
    return ( error => 000102, href => '' );
}

sub view_can_edit {
    my $self = shift;
    
    if ($self->d->{read_only}) {
        $self->template('readonly');
        return;
    }
    
    1;
}

sub session_state {
    my $self = shift;
    my $user = $self->user || return;
    my $sess = $user->{session} || return;
    
    if ($sess->{id} && @_) {
        my $state = shift;
        $self->model('UserSession')->update({ state => $state }, { id => $sess->{id} });
        $sess->{state} = $state;
    }
    
    return $sess->{state};
}

#### ------------------------------------
####    Объекты
#### ------------------------------------
#my $xname = 'IF(`abon_profile`.`is_jurical`, '.
#    'CONCAT(`abon_profile`.`jur_forma`, \' \', `abon_profile`.`jur_name`), '.
#    'CONCAT(`abon_profile`.`family`, \' \', '.
#    '`abon_profile`.`name`, \' \', `abon_profile`.`otch`)) as `xname`';
sub obj_user {
    my $self = shift;
    
    $self->object_by_model(
        'UserList',
    )
}
sub obj_grp {
    my $self = shift;
    
    $self->object_by_model(
        'UserGroup',
    )
}
sub obj_blok {
    my $self = shift;
    
    $self->object_by_model(
        'Blok',
        #where => { deleted => 0 },
        #param => { order_by => 'numid', '+columns' => [$xname] }
    )
}
sub obj_cmd {
    my $self = shift;
    
    $self->object_by_model(
        'Command',
        #where => { deleted => 0 },
        #param => { order_by => 'numid', '+columns' => [$xname] }
    )
}
sub obj_aus {
    my $self = shift;
    
    $self->object_by_model(
        'Ausweis',
        #where => { deleted => 0 },
        #param => { order_by => 'numid', '+columns' => [$xname] }
    )
}
sub obj_pre {
    my $self = shift;
    
    $self->object_by_model(
        'Preedit',
        #where => { deleted => 0 },
        #param => { order_by => 'numid', '+columns' => [$xname] }
    )
}
sub obj_event {
    my $self = shift;
    
    $self->object_by_model(
        'Event',
        #where => { deleted => 0 },
        #param => { order_by => 'numid', '+columns' => [$xname] }
    )
}







sub FormError {
    my $self = shift;
    my $err = $self->req->param_str('field_error') || return {};
    
    my %err =
        map {
            my ($f, $code) = split /-/;
            my $err = $self->c(form_errors => $code) || sprintf($self->c(form_errors => 'unknown')||'[%d]', $code);
            ($f => $err);
        }
        split /,/, $err;
    return \%err;
}

sub qsrch {
    my $self = shift;
    
    my @qsrch = grep { $_->{val} } @_;
    my %qsrch =
        map {
            my $val = $_->{val};
            _utf8_off($val);
            $_->{f} => Clib::Mould->ToUrl($val);
        }
        @qsrch;
    
    return {
        full => %qsrch ? '?' . join('&', map { $_->{f} . '=' . $qsrch{ $_->{f} } } @qsrch) : '',
        (
            map {
                my $f = $_->{f};
                my %qsrch1 = %qsrch;
                delete $qsrch1{$f};
                'no_'.$f => %qsrch1 ?
                    '?' . join('&',
                               map { $_->{f} . '=' . $qsrch1{ $_->{f} } }
                               grep { $qsrch1{ $_->{f} } }
                               @qsrch
                            ) :
                    '';
            }
            @_
        ),
    }
}


sub msg_count {
    my $self = shift;
    
    return $self->model('Msg')->count({ uid => $self->user->{id}, readed => 0 });
}

=pod
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

=cut

1;
