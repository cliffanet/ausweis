package C::Auth;
use strict;
use warnings;

sub err {
    my $self = shift;
    my $errno = shift;
    
    $self->template('auth_login');
    $self->patt(
        errno => $errno,
        error => $self->c(userError => $errno),
        @_,
    );
    
    if ($self->req->cookie('sid') || $self->req->cookie('skey')) {
        # Удаляем куки, если сессия была удалена
        $self->res->cookie(sid => '');
        $self->res->cookie(skey => '');
    }
    
    $self->user({});
    $self->admin({});
    
    return 0;
}

sub init {
    my ($self, $path) = @_;
    
    my $path_simple = $path && ($path =~ /^(login|ajax(\/[a-z0-9]+)?)$/) ? 1 : 0;
    my %p = ();
    $p{redirect} = $path if !$path_simple;
    
    # Проверяем сессию
    my ($s_id, $s_key) =
        ($self->req->cookie('sid'), $self->req->cookie('skey'));
    
    $s_id || return err($self, 0, %p);
    
    
    # Ищем сессию/пользователя (сессии без пользователя быть не должно)
    my ($user) = $self->model('UserList')->search({
            'session.id'    => $s_id,
            'session.key'   => $s_key,
        }, {
            prefetch => [qw/session group/]
        });
    
    if (!$user) {
        return err($self, 11, %p);
    }
    
    # Устанавливаем текущих пользователей
    $self->user($user);
    
    my $admin = {
        uid         => $user->{id},
        login       => $user->{login},
        urights     => $user->{rights},
    };
    use Clib::Rights;
    ($admin->{gid}, $admin->{group}, $admin->{grights}, $admin->{rights}) =
        $user->{group} && $user->{group}->{id} ?
            ($user->{group}->{id}, $user->{group}->{name}, $user->{group}->{rights}, rights_Combine($user->{rights}, $user->{group}->{rights}, 1)) :
            (0, '', '', $user->{rights});
    
    $self->admin($admin);
    
    # Проверяем глобальный доступ
    if (!$self->rcheck('global')) {
        $self->model('UserSession')->delete(
            { id => $user->{session}->{id} }
        );
        return err($self, 14, %p);
    }
    
    # Если указано, обновляем время посещения
    if (!$path_simple) {
        my $ip = $ENV{REMOTE_ADDR};
        $self->model('UserSession')->update({
            visit => \ 'NOW()',
            $ip eq $user->{session}->{ip} ?
                () : (ip => $ip),
        }, {
            id => $user->{session}->{id}
        });
    }
    
    return 1;
}

=pod       
        
        
        
        
    my $auth;
    if ($s_id) {
        my %upd =
             $ENV{PATH_INFO} && (($ENV{PATH_INFO} =~ /login$/) || ($ENV{PATH_INFO} =~ /ajax(\/[a-z0-9]+)?$/) || ($ENV{PATH_INFO} =~ /auth\/info/) || ($ENV{PATH_INFO} =~ /auth\/panel/))
             ? () : ( supd => 1 );
        $auth = $self->external(Admin => user_init => { sid => $s_id, skey => $s_key, sip => $s_ip, %upd, rcheck => 'global_advanced' } );
    }
    
    # !!!!!! ВРЕМЕННЫЙ КОСТЫЛЬ !!!!!!
    # Надо постараться перенести это все в external(Admin)
    if (!$auth || !$auth->{uid}) {
        $self->d->{auth_error} = { %{ $auth||{  } } };
    }
    
    # Глобальный доступ
    # !!!!!! ВРЕМЕННЫЙ КОСТЫЛЬ !!!!!!
    # Надо постараться перенести это все в external(Admin)
    if (my $aerr = $self->d->{auth_error}) {
        $self->debug("auth error!!!!! # %s", $aerr->{errno})
            if $aerr->{errno};
            
        # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        # Надо переделать эту проверку
        # Чтобы определять тип возврата (html, ajax, json, файл и т.д.) - и по возможности сохранять этот тип возврата
        
        #$self->view_select->subtemplate('rights_denied.tt')
        #    if $self->user && $self->user->{id} && ($self->user->{id} != 1);
        $self->d->{denied} = 1;
        if ($path && ($path !~ /login$/) && ($path !~ /ajax(\/[a-z0-9]+)?$/) && ($path !~ /auth\/info/) && ($path !~ /auth\/panel/)) {
            $self->d->{redirect} = $self->ToHtml("http://$ENV{HTTP_HOST}$ENV{REQUEST_URI}");
            
            $self->disable_dispatcher;
            $self->forward('auth/form');
        } elsif ($path =~ /login$/) {
            $self->patt->{redirect} = $self->ToHtml($self->req->param_str('redirect'));
        }
        else {
            undef $s_id;
        }
        
        if ($aerr->{deleted}) { # Удаляем куки, если сессия была удалена
            $self->res->cookie(sid => '');
            $self->res->cookie(skey => '');
        }
        return;
    }
}
=cut

sub form :
        ReturnPatt
{
    my $self = shift;
    
    if (my $user_init_errno = $self->external_data->{user_init_errno}) {
        $self->patt(errno => $user_init_errno, error =>  $self->c(userError => $user_init_errno));
    }
    if (my $redirect = $self->req->param_str('r')) {
        $self->patt(redirect => $redirect);
    }
    if (my $login_error = $self->external_data->{login_error}) {
        $self->patt(login_error => $login_error);
    }
    
    $self->patt(
        denied => 1,
        
        href_login  => $self->pref('auth/login'),
    );
    
    $self->view_select('Admin')->subtemplate('login.tt');
}

sub login :
        ReturnOperation
{
    my $self = shift;
    
    my $login    = $self->req->param_str('l');
    my $password = $self->req->param('p');
    $password = '' if !defined($password);
    my $redirect = $self->req->param_str('r');
    my $is_ajax = $self->req->param_bool('is_ajax');
    
    my %login_error = ( login => $login, $redirect ? (redirect => $redirect) : () );
    
    if (!$login) {
        $self->log3("Empty login");
        $self->external_data(login_error => { %login_error, errno => 4, error =>  $self->c(userError => 4) });
        form($self);
        return (error => 10001, field => { l => $self->c(userError => 4) });
    }
    
    my $l = $self->cmd_login({ l => $login, p => $password, ip => $self->external_data->{ip} });
    
    if (!$l) {
        $self->log3("Unknown login error");
        $self->external_data(login_error => { %login_error, errno => 5, error =>  $self->c(userError => 5) });
        $self->patt(login => $login);
        form($self);
        return (error => 10001, field => { l => $self->c(userError => 5) });
    }
    
    if ($l->{errno} || !$l->{sid} || !$l->{skey}) {
        $self->external_data(login_error => { %login_error, %$l });
        form($self);
        return (error => 10001, field => { l => $self->c(userError => $l->{errno}) });
    }
    
    $self->res->cookie(sid => $l->{sid});
    $self->res->cookie(skey => $l->{skey});
    
    return (ok => 10001, $redirect ? (redirect => $redirect) : $is_ajax ? () : (href => ''));
}

sub logout :
        ReturnOperation
{
    my $self = shift;
    
    my $l = $self->cmd_logout({});
    
    if ($l && $l->{sid}) {
        $self->res->cookie(sid => '');
        $self->res->cookie(skey => '');
    }
    
    return (href => '');
}
        
sub passform :
        Simple
{
    my $self = shift;
    
    use utf8;
    $self->patt(
        TITLE       => ' Изменение пароля',
        href_set    => $self->pref('auth/pass'),
    );
    
    $self->view_select('Admin')->subtemplate('password.tt');
}
        
sub pass :
        ReturnOperation
{
    my $self = shift;
    
    my $user = $self->user() || return (href => '');

    # Сверяем старый пароль
    my $password = $self->req->param('pso');
    $password = '' if !defined($password);
    my ($user1) = $self->model('AdminList')->search({
        id      => $user->{id},
        password=> { 'PASSWORD' => $password },
    });
    if (!$user1) {
        $self->error("Password old verify failed");
        return (error => 10301, href => '');
    }
    
    # Проверяем новый пароль
    my $passnew = $self->req->param('psn');
    my $password2 = $self->req->param('ps2');
    if (!defined($passnew) || !length($passnew)) {
        $self->error("New password empty");
        return (error => 10302, href => '');
    }
    if (!defined($password2) || ($passnew ne $password2)) {
        $self->error("New password not confirmed");
        return (error => 10303, href => '');
    }
    
    # Сохраняем данные
    $self->model('AdminList')->update(
            { password => { PASSWORD => $passnew } }, 
            { id => $user->{id} }
    ) || return (error => 100104, href => '');
    
    $self->log("Password change succeful for user: $user->{login}");
    
    return (ok => 10300, href => '');
}
        
        
        ######################################################################
        

sub user_update {
    my ($self, $user) = @_;
    
    if (!$user || !$user->{id}) {
        $self->user({});
        $self->admin({});
        return;
    }
    
    # Формируем данные в external_data
    my $admin = {
        uid         => $user->{id},
        login       => $user->{login},
        urights     => $user->{rights},
    };
    ($admin->{gid}, $admin->{group}, $admin->{grights}, $admin->{rights}) =
        $user->{group} && $user->{group}->{id} ?
            ($user->{group}->{id}, $user->{group}->{name}, $user->{group}->{rights}, rights_Combine($user->{rights}, $user->{group}->{rights}, 1)) :
            (0, '', '', $user->{rights});
    
    $self->user($user);
    $self->admin($admin);
}


sub cmd_login {
    my ($self, $p) = @_;
    
    return 0 if !defined(!$p->{l}) || ($p->{l} eq '');
    return 0 if !defined(!$p->{p});
    
    my $err = sub {
        my $errno = shift;
        return { errno => $errno, error => $self->c(userError => $errno) };
    };
    
    # Проверяем логин и пароль
    my ($user) = $self->model('AdminList')->search({
        login       => $p->{l},
        password    => { 'PASSWORD' => $p->{p} },
    }, {
        prefetch    => ['group'],
    });
    
    if (!$user || !$user->{id}) {
        $self->log3("Authentication failed for user: $p->{l}");
        
        # Если логин и пароль не подошли,
        # Всем сессиям с этим логином принудительно задаем state = "под вашим аккаунтом была неудачная попытка входа"
        my (@users) = $self->model('AdminList')->search({ login => $p->{l} });
        if (@users) {
            $self->model('AdminSession')->update(
                { state => -11102 },
                { uid => [map { $_->{id} } @users] }
            );
        }
        
        return $err->( 1 );
    }
    
    $self->log3("Authentication succeful for user: $p->{l} (".$user->{login}.")");
    
    
    # Создаем новую сессию
    my $session = {
        key     => int(rand(0xFFFFFFFF)),
        ip      => $p->{ip} || '',
        create  => \ 'NOW()',
        visit   => \ 'NOW()',
        uid     => $user->{id},
    };
    
    # Определяем таймауты
    my $time = time;
    my $expire = $user->{sessidle} || $user->{group}->{sessidle} || $self->c(session => 'idle') || 0;
    $session->{expire} = $time + $expire if $expire > 0;
    my $expiremax = $user->{sessmax} || $user->{group}->{sessmax} || $self->c(session => 'max') || 0;
    $session->{expiremax} = $time + $expiremax if $expiremax > 0;
    my $sessmaxtime = $user->{sessmaxtime} || $user->{group}->{sessmaxtime} || $self->c(session => 'maxtime') || '';
    if ($sessmaxtime =~ /^(\d+)\:(\d+)(\:(\d+))?$/) {
        # определяем время суток, когда сессия будет сброшена принудительно
        my ($hr, $mr) = ($1, $2);
        # Получаем указанное время в текущих сутках
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
        $sessmaxtime = timelocal(0, $mr, $hr, $mday, $mon, $year);
        # Добавляем еще сутки, если оказалось, что на сегодня это время уже прошло
        $sessmaxtime += 3600*24 if $sessmaxtime < $time;
        # Используем полученное время в качесте expiremax, если expiremax не указан, либо указывает на более позднее время
        # Более приоритетное время сброса - ближайшее по времени
        $session->{expiremax} = $sessmaxtime if ($session->{expiremax} <= 0) || ($session->{expiremax} > $sessmaxtime);
    }
    
    # Пишем в БД
    if (!$self->model('AdminSession')->create($session)) {
        $self->_error(__PACKAGE__, "Can't create session");
        
        return $err->( 2 );
    }
    my $s_id = $self->model('AdminSession')->insertid;
    # Читаем заного пользователя с сессией
    ($user) = $self->model('AdminList')->search({
            'id'            => $user->{id},
            'session.id'    => $s_id,
        }, {
            prefetch => [qw/session group/]
        });
    $user || return $err->( 2 );
    
    $self->user_update($user);
    $session = $user->{session};
    
    
    # Всем остальным сессиям говорим "давай-досвидания"
    $self->model('AdminSession')->update(
        { closed => 13 },
        {
            uid => $user->{id},
            id  => { '!=' => $session->{id} },
            #ip  => { '!=' => $self->session->{ip} },
        }
    );
    
    return { sid => $session->{id}, skey => $session->{key} };
}

sub cmd_logout {
    my ($self, $p) = @_;
    
    my ($user) =
        $p->{sid} && $p->{skey} ?
            $self->model('AdminList')->search({
                'session.id'    => $p->{sid},
                'session.key'   => $p->{skey},
            }, {
                prefetch => [qw/session group/]
            })
        :
            $self->user;
    
    $user || return { errno => 11, error => $self->c(userError => 11) };
    
    $self->model('AdminSession')->delete({ id => $user->{session}->{id} })
        || return { errno => 3, error => $self->c(userError => 3) };
    
    $self->log3("Logout: $user->{login}");
    
    return { uid => $user->{id}, sid => $user->{session}->{id}, skey => $user->{session}->{key} };
}


sub cmd_state {
    my ($self, $p) = @_;
    
    my ($user) =
        $p->{uid} && $p->{sid} ?
            $self->model('AdminList')->search({
                'id'            => $p->{uid},
                'session.id'    => $p->{sid},
            }, {
                prefetch => [qw/session group/]
            })
        :
            $self->user;
    
    $user || return { errno => 11, error => $self->c(userError => 11) };
    
    defined($p->{state}) || return {};
    return { state => $p->{state} } if $p->{state} == $user->{session}->{state};
    
    $self->model('AdminSession')->update({ state => $p->{state} }, { id => $user->{session}->{id} });
    
    return { state => $p->{state} };
}


sub obj_user {
    my $self = shift;
    
    $self->object_by_model(
        'AdminList',
        param => { columns => [qw/id login/] }
    ),
}


1;
