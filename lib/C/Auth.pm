package C::Auth;
use strict;
use warnings;

sub init {
    my ($self, $path) = @_;
    
    my $is_login = $path && ($path =~ /^\/?auth\/login$/) ? 1 : 0;
    
    my %p = ();
    $p{redirect} = $path if $path && !$is_login && ($path !~ /^\/?(ajax(\/[a-z0-9]+)?)$/);
    
    # Проверяем сессию
    my ($s_id, $s_key) =
        ($self->req->cookie('sid'), $self->req->cookie('skey'));
    
    $s_id || return err($self, 0, %p) || $is_login;
    
    
    # Ищем сессию/пользователя (сессии без пользователя быть не должно)
    my ($user) = $self->model('UserList')->search({
            'session.id'    => $s_id,
            'session.key'   => $s_key,
        }, {
            prefetch => [qw/session group/]
        });
    
    if (!$user) {
        return err($self, 11, %p) || $is_login;
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
        return err($self, 14, %p) || $is_login;
    }
    
    # Если указано, обновляем время посещения
    if ($p{redirect}) {
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

sub form {
    my $self = shift;
    my $errno = shift;
    
    $self->template('auth_login');
    $self->patt(
        errno => $errno,
        error => $self->c(userError => $errno),
        login => '',
        redirect => '',
        @_,
    );
    
    return view => 1;
}

sub err {
    my $self = shift;
    my $errno = shift;
    
    form($self, $errno, @_);
    
    if ($self->req->cookie('sid') || $self->req->cookie('skey')) {
        # Удаляем куки, если сессия была удалена
        $self->res->cookie(sid => '');
        $self->res->cookie(skey => '');
    }
    
    $self->user({});
    $self->admin({});
    
    return 0;
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
    
    my %error = ( login => $login, $redirect ? (redirect => $redirect) : () );
    
    foreach my $s ($login, $password) {
        Encode::_ut8_on(_utf8_on($s));
    }
    
    # Проверяем логин и пароль
    if (!$login) {
        $self->log("Empty login");
        return form($self, 4, %error);
    }
    
    my ($user) = $self->model('UserList')->search({
        login       => $login,
        password    => { 'PASSWORD' => $password },
    }, {
        prefetch    => ['group'],
    }, nolog => 0);
    
    if (!$user || !$user->{id}) {
        $self->log("Authentication failed for user: %s", $login);
        return form($self, 1, %error);
    }
    
    $self->log("Authentication succeful for user: %s (%s)", $login, $user->{login});
    
    
    # Создаем новую сессию
    my $session = {
        key     => int(rand(0xFFFFFFFF)),
        ip      => $ENV{REMOTE_ADDR} || '',
        create  => \ 'NOW()',
        visit   => \ 'NOW()',
        uid     => $user->{id},
    };
    if (!$self->model('UserSession')->create($session)) {
        $self->log("Can't create session");
        return form($self, 2, %error);
    }
    
    my $s_id = $self->model('UserSession')->insertid;
    # Читаем заного пользователя с сессией
    ($user) = $self->model('UserList')->search({
            'id'            => $user->{id},
            'session.id'    => $s_id,
        }, {
            prefetch => [qw/session group/]
        });
    $user || return form($self, 2, %error);
    
    $self->user($user);
    
    $self->res->cookie(sid => $s_id);
    $self->res->cookie(skey => $session->{key});
    
    return (ok => 10100, $redirect ? (redirect => $self->href($redirect)) : $is_ajax ? () : (href => ''));
}

sub logout :
        ReturnOperation
{
    my $self = shift;
    
    my $user = $self->user;
    $user = undef if $user && (!$user->{id} || !$user->{session} || !$user->{session}->{id});
    
    $user || return form($self, 11);
    
    $self->model('UserSession')->delete({ id => $user->{session}->{id} })
        || return (error => 000104, href => '');
    
    $self->res->cookie(sid => '');
    $self->res->cookie(skey => '');
    
    $self->log("Logout: %s", $user->{login});
    
    return (href => '');
}
        
sub pform :
        ReturnPatt
{
    my $self = shift;
    
    my $user = $self->user() || return;
    $self->template('auth_pass');
}
        
sub pass :
        ReturnOperation
{
    my $self = shift;
    
    my $user = $self->user() || return (href => '');

    # Сверяем старый пароль
    my $password = $self->req->param('p');
    $password = '' if !defined($password);
    my ($user1) = $self->model('UserList')->search({
        id      => $user->{id},
        password=> { 'PASSWORD' => $password },
    });
    if (!$user1) {
        $self->error("Password old verify failed");
        return (error => 10301, pref => 'auth/pform');
    }
    
    # Проверяем новый пароль
    my $passnew = $self->req->param('pn');
    my $password2 = $self->req->param('p2');
    if (!defined($passnew) || !length($passnew)) {
        $self->error("New password empty");
        return (error => 10302, href => '');
    }
    if (!defined($password2) || ($passnew ne $password2)) {
        $self->error("New password not confirmed");
        return (error => 10303, href => '');
    }
    
    # Сохраняем данные
    $self->model('UserList')->update(
            { password => { PASSWORD => $passnew } }, 
            { id => $user->{id} }
    ) || return (error => 100104, href => '');
    
    $self->log("Password change succeful for user: $user->{login}");
    
    return (ok => 10300, href => '');
}
        
        
        ######################################################################


sub obj_user {
    my $self = shift;
    
    $self->object_by_model(
        'AdminList',
        param => { columns => [qw/id login/] }
    ),
}


1;
