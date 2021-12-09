package CMain::Auth;

use Clib::strict8;
use Clib::Web::Controller; # webctrl_search

sub sessnew {
    my %p = @_;
    
    my $time = time;
    
    my $skey = int(rand(0xFFFFFFFF));
    my @sess = (
        key     => $skey,
        ip      => $ENV{REMOTE_ADDR} || '',
        dtbeg   => Clib::DT::now(),
        dtact   => Clib::DT::now(),
        @_,
    );
    
    # Пишем в БД
    my $sid = sqlAdd(user_session => @sess);
    if (!$sid) {
        logauth('AUTH: Can\'t create session');
        return;
    }
    
    WebMain::login(session => { id => $sid, @sess });
    
    # Наконец, всё ок, пишем куки
    Clib::Web::Param::cookieset(sid => $sid, path => '/');
    Clib::Web::Param::cookieset(skey => $skey, path => '/');
    
    return $sid;
}

sub sesscheck {
    my %c = WebMain::web_cookie();
    my $ip = $ENV{REMOTE_ADDR};
    
    return
        if !$ip || !$c{sid} || !$c{skey};
    
    my @r = (ip => $ip);
    
    # Ищем и проверяем сессию пользователя
    my ($sess) = sqlSrch(user_session => id => $c{sid}, key => $c{skey});
    
    if (!$sess) {
        Clib::Web::Param::cookieset(sid => '', path => '/', delete => 1);
        Clib::Web::Param::cookieset(skey => '', path => '/', delete => 1);
        return errno => 'nosess', @r;
    }
    
    push @r, session => $sess;
    
    if (!$sess->{uid}) {
        # Это временная сессия
        return @r;
    }
    
    # Ищем пользователя
    my $user = sqlGet(user_list => $sess->{uid});
    if (!$user) {
        logauth('SESSION: UNKNOWN UID=%s', $sess->{uid});
        return errno => 'sessinf', @r;
    }
    my @u = (user => $user);
    
    # Пароль пустой - глобальный запрет доступа
    if ($user->{password} eq '') {
        logauth('SESSION: Empty password on user: %s', $user->{login});
        return errno => 'rdenied', @r;
    }
    
    my $rights = $user->{rights};
    
    # группа
    if (my $gid = $user->{gid}) {
        my $grp = sqlGet(user_group => $gid);
        if (!$grp) {
            logauth('SESSION: Group[gid=%d] not found on user: %s', $gid, $user->{login});
            return errno => 'ugroup', @r;
        }
        
        $rights = Clib::Rights::combine($user->{rights}, $grp->{rights});
        
        push @u, group => $grp;
    }
    
    # Права доступа
    if (!WebMain::_rchk($rights, 'global')) {
        logauth('SESSION: No global access on user: %s', $user->{login});
        return errno => 'rdenied', @r;
    }
    push @u, rights => $rights;
    
    # обновляем время посещения
    sqlUpd(user_session => $sess->{id}, dtact => Clib::DT::now())
        || return errno => 'sessupd', @r;
    
    return @r, @u;
}

sub _root :
        AllowNoAuth
        Title('Авторизация')
{
    my @p = ();
    my $p = wparam();
    
    # ссылка для редиректа
    my ($disp, @disp) = ();
    if (my $path = $p->raw('ar')) {
        debug('auth-form redirect path: %s', $path);
        ($disp, @disp) = webctrl_search($path);
    }
    elsif (my $href = WebMain::path_referer()) {
        debug('auth-form redirect referer: %s', $href);
        $path = WebMain::path_short($href);
        ($disp, @disp) = webctrl_search($path) if defined $path;
    }
    if ($disp && (($disp->{path} ne '') || @disp) && (($disp->{path} !~ /^auth/))) {
        my $ar = WebMain::pref_short($disp->{path}, @disp);
        if ($ar && ($ar !~ /^auth/)) {
            push @p, ar => $ar;
            debug('auth-form redirect to: %s', $ar);
        }
    }
    
    return 'auth_form', @p;
}

sub login :
        AllowNoAuth
        Title('Авторизация (выполнение)')
        ReturnOperation
{
    my $p = wparam();
    my $login    = $p->str('l');
    my $password = $p->raw('p');
    $password = '' if !defined($password);
    
    my @err = (pref => 'auth');

    my $path = $p->raw('ar');
    if ($path) {
        debug('auth-login redirect path: %s', $path);
        if (!webctrl_search($path)) {
            error('auth-login redirect fail path: %s', $path);
            $path = '';
        }
    }
    push(@err, query => [ar => $path]) if $path;
    
    # Проверка логина
    if ($login eq '') {
        logauth('AUTH: Empty login');
        return err => c(state => loginerr => 'empty'), @err;
    }
    
    # Хорошо бы передавать логин через msg, чтобы в случае редиректа он уже был автоматически введён,
    # однако, если будет ошибка авторизации (например, при подборе пароля), то каждый раз
    # будет создаваться сессия с сохранённым логином, которая не будет стираться до таймаута,
    # пока не будет открыта страница. При ajax-авторизации такое, например, вообще штатно происходит.
    # Поэтому, чтобы не делать лишних сохранений в БД и вообще лишних действий, сохранять логин не будем
    #push @err, login => $login;
    
    # Проверяем существование аккаунта
    my ($user) = sqlSrch(user_list => login => $login, sqlPassword(password => $password));
    
    if (!$user || !$user->{id}) {
        logauth('AUTH: Unknown user: %s', $login);
        return err => c(state => loginerr => 'wrong'), @err;
    }
    
    # Проверяем пароль
    if ($user->{password} eq '') {
        # Пароль пустой - глобальный запрет доступа
        logauth('AUTH: Empty password on user: %s', $login);
        return err => c(state => loginerr => 'wrong'), @err;
    }
    
    logauth('AUTH: Succeful for user: %s', $user->{login});
    
    # Создаем новую сессию
    my $sid = sessnew(uid => $user->{id})
        || return err => c(state => loginerr => 'sessadd'), @err;
    WebMain::login(user => $user);
    
    return ok => c(state => 'loginok'), pref => $path||'/';
}

sub logout :
        Title('Выход из системы')
        ReturnOperation
{
    my %auth = WebMain::auth();
    my $sess = $auth{session}
        || return err => c(state => loginerr => 'nosess');
    
    logauth('LOGOUT: %s', ($auth{user}||{})->{login});
    
    sqlDel(user_session => $sess->{id});
    
    Clib::Web::Param::cookieset(sid => '', path => '/', delete => 1);
    Clib::Web::Param::cookieset(skey => '', path => '/', delete => 1);
    
    WebMain::logout();
    
    return ok => c(state => 'logout'), pref => 'auth';
}
        
sub pform :
        Simple
{
    return 'auth_pass';
}
        
sub pchg :
        ReturnOperation
{
    my $user = WebMain::auth('user')
        || return pref => 'auth';
    
    my $p = wparam();
    
    # Сверяем старый пароль
    my $password = $p->raw('p');
    $password = '' if !defined($password);
    my ($u1) = sqlSrch(user_list => id => $user->{id}, sqlPassword(password => $password));
    if (!$u1) {
        logauth('PASSCHANGE: Current verify failed');
        return err => c(state => passchg => 'current'), pref => 'auth/pform';
    }
    
    # Проверяем новый пароль
    my $passnew = $p->raw('pn');
    my $password2 = $p->raw('p2');
    if (!defined($passnew) || !length($passnew)) {
        logauth('PASSCHANGE: New empty');
        return err => c(state => passchg => 'newempty'), pref => 'auth/pform';
    }
    if (!defined($password2) || ($passnew ne $password2)) {
        logauth('PASSCHANGE: Not confirmed');
        return err => c(state => passchg => 'confirm'), pref => 'auth/pform';
    }
    
    # Сохраняем данные
    sqlUpd(
        user_list => $user->{id},
        password => [PASSWORD => $passnew]
    ) || return err => 'db', pref => 'auth/pform';

    logauth('PASSCHANGE: Succeful for user: %s', $user->{login});
    
    return ok => c(state => passchg => 'ok'), pref => '/';
}

1;
