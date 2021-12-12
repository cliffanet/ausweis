package WebMain;

use Clib::strict8;
use Clib::Const;
use Clib::Log;
use Clib::Web::Controller;
use Clib::Web::Param;
use Clib::DB::MySQL 'DB';
use Clib::Template::Package;
use Clib::DT;
use Clib::Rights;

use ImgFile;

use JSON::XS;

$SIG{__DIE__} = sub { error('DIE: %s', $_) for @_ };

my $logpid = log_prefix($$);
my $logip = log_prefix('init');
my $loguser = log_prefix('');

my $href_prefix = '';
sub pref_short {
    my $href = webctrl_pref(@_);
    if (!defined($href)) {
        $href = '';
        #dumper 'pref undefined: ', \@_;
    }
    return $href;
}
sub pref { return $href_prefix . '/' . pref_short(@_); }

sub path_short {
    my $path = shift() || return;
    
    if ($href_prefix ne '') {
        if (substr($path, 0, length($href_prefix)) ne $href_prefix) {
            return;
        }
        substr($path, 0, length($href_prefix)) = '';
    }
    
    $path =~ s/^\///;
    
    return $path;
}

webctrl_local(
        'CMain',
        attr => [qw/Title AllowNoAuth ReturnOperation ReturnRedirect ReturnBlock ReturnFile/],
        eval => "
            use Clib::Const;
            use Clib::Log;
            use Clib::DB::MySQL;
            
            *wparam = *WebMain::param;
            *rchk = *WebMain::rchk;
            *editable = *WebMain::editable;
            *qsrch = *WebMain::qsrch;
            *form = *WebMain::form;
        ",
    ) || die webctrl_error;

# get/post параметры
my $param;
sub param { $param ||= Clib::Web::Param::param(prepare => 1, @_) }

# авторизация
my %auth = ();
sub auth { @_ ? $auth{shift()} : %auth };
sub login {
    while (@_) {
        my $key = shift;
        $auth{$key} = shift;
    }
}
sub logout {
    delete($auth{$_}) foreach qw/session user group/;
}

# Формирование query для фильтра
sub qsrch {
    my @fld = ref($_[0]) eq 'ARRAY' ? @{ shift() } : ();
    my $r = {};
    
    $r->{full} = Clib::Web::Param::data2url(@_);
    $r->{full} = '?'.$r->{full} if $r->{full};
    $r->{'no_'.$_} = $r->{full} foreach @fld;
    
    my @p = ();
    while (@_) {
        my $f = shift();
        my $v = shift();
        
        my $q = Clib::Web::Param::data2url(@p, @_);
        $q = '?'.$q if $q;
        $r->{'no_'.$f} = $q;
        
        push @p, $f => $v;
    }
    
    
    return $r;
}

# Права
my %rchk = ();
sub _rchk {
    my $rights = shift() || return;
    my $rcode = shift() || return;
    my $rchk = $rchk{$rcode} || return;
    
    return $rchk->($rights);
}
sub rchk { _rchk($auth{rights}, @_); }

# БД в режиме "только чтение"
sub editable {
    return c('read_only') ? 0 : 1;
}

# json
sub tojson {
    my $data = shift;
    return eval { JSON::XS->new->utf8->pretty(0)->canonical->encode($data); };
}
sub jdata {
    my $d = shift() || return;
    return eval { JSON::XS->new->decode($d); };
}

# сохранённые данные формы в случае ошибки
sub form {
    my $sess = $auth{session} || return;
    
    # Сохранённые данные
    my %ferr = ();
    my %form = ();
    if (my $f = $sess->{form}) {
        $f = jdata($f) || {};
        
        if (%$f) {
            if (!$f->{dst} || !$auth{path} || ($f->{dst} ne $auth{path})) {
                error('[form] `dst` fail: dst=%s, path=%s', defined($f->{dst})?$f->{dst}:'-undef', defined($auth{path})?$auth{path}:'-undef-');
                $f = {};
            }
        }
        else {
            error('[form] data fail');
        }
        
        if (%$f) {
            %ferr = %{ $f->{ferr}||{} };
            foreach my $k (keys %ferr) {
                my $msg = c(form_errors => $ferr{$k}) || next;
                $ferr{$k} = $msg;
            }
            
            my @par = @{ $f->{par}||[] };
            while (@par && (my ($k, $v) = splice(@par, 0, 2))) {
                next if exists $form{$k};
                $form{$k} = $v;
            }
        }
        else {
            # в любой непонятной ситуации стираем сохранённые данные из БД
            sqlUpd(user_session => $sess->{id}, form => undef);
        }
    }
    
    # Заполнение исходными данными
    foreach my $f (@_) {
        if (ref($f) eq 'HASH') {
            # Существующая запись
            foreach my $k (keys %$f) {
                next if exists $form{$k};
                $form{$k} = $f->{$k};
            }
        }
        else {
            # пустое поле новой записи
            next if exists $form{$f};
            $form{$f} = '';
        }
    }
    
    return form => \%form, ferr => \%ferr;
}

# инициализация
sub init {
    my %p = @_;
    
    $logpid->set($$);
    
    $href_prefix = $p{href_prefix} if $p{href_prefix};

    # права
    my %num = ();
    if (my $rights = c('rights')) {
        foreach my $r (@$rights) {
            ref($r) || next;
            my ($name, $num, $title, @variant) = @$r;
            $num{$name} = $num;
        }
    }
    my %val = ();
    if (my $rtypes = c('rtypes')) {
        foreach my $r (@$rtypes) {
            ref($r) || next;
            my ($name, $val, $title) = @$r;
            $val{$name} = $val;
        }
    }
    
    %rchk = (
        global          => sub { Clib::Rights::chk($_[0],    $num{Main},     $val{Yes}); },
        
        admin_read      => sub { Clib::Rights::exists($_[0],   $num{Admins}); },
        admin_write     => sub { Clib::Rights::chk($_[0],    $num{Admins},   $val{Write}); },
        
        msg_read       => sub { Clib::Rights::exists($_[0],   $num{Msg}); },
        msg_cfg        => sub { Clib::Rights::chk($_[0],    $num{Msg},   $val{Advanced}); },
        
        blok_list       => sub { Clib::Rights::exists($_[0],   $num{BlokList}); },
        blok_info       => sub { Clib::Rights::exists($_[0],   $num{BlokInfo}); },
        blok_info_all   => sub { Clib::Rights::chk($_[0],    $num{BlokInfo}, $val{All}); },
        blok_edit       => sub { Clib::Rights::exists($_[0],   $num{BlokEdit}); },
        blok_edit_all   => sub { Clib::Rights::chk($_[0],    $num{BlokEdit}, $val{All}); },
        blok_file       => sub { Clib::Rights::exists($_[0],   $num{BlokInfo}) ||
                                 Clib::Rights::exists($_[0],   $num{CommandInfo}); },
        blok_file_all   => sub { Clib::Rights::chk($_[0],    $num{BlokInfo}, $val{All}) ||
                                 Clib::Rights::chk($_[0],    $num{CommandInfo}, $val{All}); },
        
        command_list    => sub { Clib::Rights::exists($_[0],   $num{CommandList}); },
        command_info    => sub { Clib::Rights::exists($_[0],   $num{CommandInfo}); },
        command_info_all=> sub { Clib::Rights::chk($_[0],    $num{CommandInfo}, $val{All}); },
        command_edit    => sub { Clib::Rights::exists($_[0],   $num{CommandEdit}); },
        command_edit_all=> sub { Clib::Rights::chk($_[0],    $num{CommandEdit}, $val{All}); },
        command_logo    => sub { Clib::Rights::exists($_[0],   $num{CommandLogo}); },
        command_logo_all=> sub { Clib::Rights::chk($_[0],    $num{CommandLogo}, $val{All}); },
        command_file    => sub { Clib::Rights::exists($_[0],   $num{CommandInfo}) ||
                                 Clib::Rights::exists($_[0],   $num{CommandInfo}); },
        command_file_all=> sub { Clib::Rights::chk($_[0],    $num{CommandInfo}, $val{All}) ||
                                 Clib::Rights::chk($_[0],    $num{AusweisInfo}, $val{All}); },
        
        ausweis_list    => sub { Clib::Rights::exists($_[0],   $num{AusweisList}); },
        ausweis_info    => sub { Clib::Rights::exists($_[0],   $num{AusweisInfo}); },
        ausweis_info_all=> sub { Clib::Rights::chk($_[0],    $num{AusweisInfo}, $val{All}); },
        ausweis_edit    => sub { Clib::Rights::exists($_[0],   $num{AusweisEdit}) ||
                                 Clib::Rights::exists($_[0],   $num{AusweisPreEdit}); },
        ausweis_edit_all=> sub { Clib::Rights::chk($_[0],    $num{AusweisEdit}, $val{All}) ||
                                 Clib::Rights::chk($_[0],    $num{AusweisPreEdit}, $val{All}); },
        ausweis_pree    => sub {!Clib::Rights::exists($_[0],   $num{AusweisEdit}) &&
                                 Clib::Rights::exists($_[0],   $num{AusweisPreEdit}); },
        ausweis_pree_all=> sub {!Clib::Rights::chk($_[0],    $num{AusweisEdit}, $val{All}) &&
                                 Clib::Rights::chk($_[0],    $num{AusweisPreEdit}, $val{All}); },
        ausweis_file    => sub { Clib::Rights::exists($_[0],   $num{AusweisInfo}); },
        ausweis_file_all=> sub { Clib::Rights::chk($_[0],    $num{AusweisInfo}, $val{All}); },
        
        preedit_first   => sub { Clib::Rights::exists($_[0],   $num{Preedit}); },
        preedit_op      => sub { Clib::Rights::exists($_[0],   $num{Preedit}); },
        preedit_hide    => sub { Clib::Rights::exists($_[0],   $num{CommandInfo}); },
        preedit_cancel  => sub { Clib::Rights::exists($_[0],   $num{PreeditCancel}); },
        preedit_cancel_all=>sub{ Clib::Rights::chk($_[0],    $num{PreeditCancel}, $val{All}); },
        
        event_read      => sub { Clib::Rights::exists($_[0],   $num{Event}); },
        event_edit      => sub { Clib::Rights::chk($_[0],    $num{Event}, $val{Write}, $val{Advanced}); },
        event_advanced  => sub { Clib::Rights::chk($_[0],    $num{Event}, $val{Advanced}); },
    );
}

# обработка запросов
sub request {
    my $path = shift;
    
    # Инициализация запроса
    my $count = Clib::TimeCount->run();
    $logpid->set($$.'/'.$count);
    $logip->set($ENV{REMOTE_ADDR}||'-noip-');
    log('request %s', $path);
    
    # Проверка указанного запроса
    my ($disp, @disp) = webctrl_search($path);
    my $logdisp;
    if ($disp) {
        log('dispatcher found: %s (%s)', $disp->{symbol}, $disp->{path});
        #dumper 'disp: ', $disp;
        $logdisp = log_prefix($disp->{path});
    }
    else {
        error("dispatcher not found (redirect to /404)");
        #dumper \%ENV;
        return '', '404 Not found', 'Content-type' => 'text/plain', Pragma => 'no-cach';
    }
    
    # Проверка авторизации
    %auth = CMain::Auth::sesscheck();
    if (my $user = $auth{user}) {
        $loguser->set($user->{login});
        
        $auth{path} = $path;
        $auth{path} =~ s/^\///;
    }
    elsif (!(grep { $_->[0] =~ /allownoauth/i } @{$disp->{attr}||[]})) {
        error("dispatcher not allowed whithout auth (redirect to /auth)");
        my $autherr = $auth{errno} || 'noauth';
        my @attr = map { $_->[0] } @{($disp||{})->{attr}||[]};
        if (grep { /return(operation|json)/i } @attr) {
            return return_operation(
                    error       => c(state => loginerr => $autherr)||$autherr,
                    loginerr    => $autherr,
                    pref        => 'auth',
                );
        }
        elsif (grep { /return(simple|block)/i } @attr) {
            return '', undef, 'Content-type' => 'text/html; charset=utf-8';
        }
        else {
            my $url = redirect_url('auth');
            my $ar = pref_short($disp->{path}, @disp);
            if ($ar && ($ar ne 'auth')) {
                $ar = '/' . $ar;
                debug('auth-form redirect to: %s', $ar);
                $url .= '?ar='.$ar;
            }
            return '', undef, Location => $url;
        }
    }
    
    # Выполняем обработчик
    my @web = ();
    {
        local $SIG{ALRM} = sub { error('Too long request do: %s (%s)', $disp->{path}, $path); };
        alarm(20);
        @web = webctrl_do($disp, @disp);
        alarm(0);
    }
    
    # Делаем вывод согласно типу возвращаемого ответа
    my %ret =
            map {
                my ($name, @p) = @$_;
                $name =~ /^return(.+)$/i ?
                    (lc($1) => [@p]) : ();
            }
            @{$disp->{attr}||[]};
        
    if ($ret{debug}) {
        require Data::Dumper;
        return
            join('',
                Data::Dumper->Dump(
                    [ $disp, \@disp, \@web, \%ENV, Clib::TimeCount->info],
                    [qw/ disp ARGS RETURN ENV RunCount RunTime /]
                )
            ),
            undef,
            'Content-type' => 'text/plain';
    }
    
    elsif ($ret{operation})  {
        return return_operation(@web);
    }
    
    elsif ($ret{redirect})  {
        return return_redirect(@web);
    }
    
    elsif ($ret{block})  {
        return return_block(@web);
    }

    elsif ($ret{file})  {
        return return_file(@web);
    }
    
    else {
        return return_default(@web);
    };
}

sub clear {
    $logip->set('-clear-');
    $loguser->set('');
    %auth = ();
    undef $param;
    Clib::Web::Param::cookiebuild();
}

my $module_dir = c('template_module_dir');

if ($module_dir) {
    $module_dir = Clib::Proc::ROOT().'/'.$module_dir if $module_dir !~ /^\//;
}

my $proc;

sub tmpl_init {
    $proc && return $proc;
    
    my $log = log_prefix('Template::Package init');
    
    my %callback = (
        script_time     => \&Clib::TimeCount::interval,
        
        pref            => \&pref,
        #href_this       => sub {  },
        
        tmpl =>  sub {
            my $name = shift;
            my $tmpl = $proc->tmpl($name);
            if (!$tmpl) {
                error("tmpl('%s')> %s", $name, $proc->error());
            }
            return $tmpl;
        },
    );
    
    
    $proc = Clib::Template::Package->new(
        FILE_DIR    => Clib::Proc::ROOT().'/template',
        $module_dir ? (MODULE_DIR => $module_dir) : (),
        c('template_force_rebuild') ?
            (FORCE_REBUILD => 1) : (),
        USE_UTF8    => 1,
        CALLBACK    => \%callback,
        debug       => sub { debug(@_) }
    );
    
    if (!$proc) {
        error("on create obj: %s", $!||'-unknown-');
        return;
    }
    if (my $err = $proc->error) {
        undef $proc;
        error($err);
        return;
    };
    
    foreach my $plugin (qw/Base HTTP Block Misc/) {
        if (!$proc->plugin_add($plugin)) {
            undef $proc;
            error("plugin_add: %s", $proc->error);
            return;
        };
    }
    
    foreach my $parser (qw/Html/) {# jQuery/) {
        if (!$proc->parser_add($parser)) {
            undef $proc;
            error("parser_add: %s", $proc->error);
            return;
        };
    }
    
    $proc;
}

sub tmpl {
    $proc || tmpl_init() || return;
    
    my $tmpl = $proc->tmpl(@_);
    if (!$tmpl) {
        error("template(%s) compile: %s", $_[0], $proc->error);
        return;
    }
    
    return $tmpl;
}

sub return_html {
    my $base = shift;
    my $name = shift;
    my $block = shift;
    
    if (!$base && !$name) {
        return '', undef, 'Content-type' => 'text/html; charset=utf-8';
    }
    
    my $tmpl = $base ?
        tmpl($name, $base) :
        tmpl($name);
    $tmpl || return;
    
    my @p = (
        href_base => pref(''),
        auth => \%auth,
        ver => {
            original=> c('version'),
            full    => c('version') =~ /^(\d*\.\d)(\d*)([a-zA-Z])?$/ ? sprintf("%0.1f.%d%s", $1, $2 || 0, $3?'-'.$3:'') : c('version'),
            date    => Clib::DT::date(c('versionDate')),
        }
    );
    
    if ($auth{user} && !$block) {
        # Команда
        if ($auth{user} && (my $cmdid = $auth{user}->{cmdid})) {
            my $cmd = sqlGet(command => $cmdid);
            push(@p, mycmd => $cmd) if $cmd;
        }
    
        # state
        if (my $sess = $auth{session}) {
            if (defined $sess->{state}) {
                push @p, state => $sess->{state};
                sqlUpd(user_session => $sess->{id}, state => undef);
                $sess->{state} = undef;
            }
        }
        
        # menu
        push @p, menu => [menu()];
    }
    
    my $meth = 'html';
    $meth .= '_'.$block if $block;

    return
        $tmpl->$meth({ @_, @p, RUNCOUNT => Clib::TimeCount->count() }),
        undef,
        'Content-type' => 'text/html; charset=utf-8';
}

sub return_simple { return return_html('', shift(), '', @_); }

sub return_block { return return_html('', @_); }

sub return_default { return return_html('base', shift(), '', @_); }

sub return_operation {
    my %p = @_;
    
    $p{err} = 'input' if !($p{err}||$p{error}) && $p{ferr};
    
    # Ключ ok/err/error содержат текстовое сообщение о статусе выполненной операции
    # Могут сохранять либо сам текст, либо ключ стандартных сообщений
    foreach my $k (qw/ok err error/) {
        my $msg = $p{$k} || next;
        my $msg1 = c(state => std => $msg) || next;
        $p{$k} = $msg1;
    }
    
    my $p = param();
    
    if ($p && $p->bool('ajax')) {
        my @json = ();
        if (my $msg = $p{ok}) {
            push @json, ok => 1, message => $msg;
            # В аякс-версии редирект используется только при успешном сообщении
            if (exists $p{pref}) {
                my $ref =
                    ref($p{pref}) eq 'ARRAY' ?
                        pref(@{ $p{pref} }) :
                    $p{pref} ?
                        pref($p{pref}) :
                        path_referer();
                push(@json, redirect => $ref) if $ref;
            }
        }
        else {
            push @json, error => 1;
            if (my $err = $p{error} || $p{err}) {
                push @json, message => $err;
            }
            else {
                error("CRITICAL: return_operation whithout `ok` or `err`");
            }
            if (my $fld = $p{field}) {
                push @json, field => {
                    map { ( $_ => c(field => $fld->{$_}) || $fld->{$_} ) }
                    keys %$fld
                };
            }
        }
        foreach my $k (qw/err_field fld/) {
            my $v = $p{$k} || next;
            push @json, $k => $v;
        }
        
        #dumper('ajax return: ', @json);
        
        return return_json(@json);
    }
    
    if (my $sess = $auth{session}) {
        if ($p{ok}) {
            my @f = (state => 'ok');
            
            if ($sess->{form}) {
                push @f, form => undef;
            }
            
            sqlUpd(user_session => $sess->{id}, @f);
        }
        elsif (my $err = $p{error} || $p{err}) {
            my @f = (state => $err);
            
            if (my $f = $p{ferr}) {
                my $d = { ferr => $f, par => [ param()->orig() ] };
                if (my $p = $p{pref}) {
                    $d->{dst} = webctrl_pref(ref($p) eq 'ARRAY' ? @$p : $p);
                }
                
                push @f, form => tojson($d);
            }
            elsif ($sess->{form}) {
                push @f, form => undef;
            }
            
            sqlUpd(user_session => $sess->{id}, @f);
        }
        else {
            error("CRITICAL: return_operation whithout `ok` or `err`");
            if (defined $sess->{state}) {
                sqlUpd(user_session => $sess->{id}, state => undef);
                $sess->{state} = undef;
            }
        }
    }
    
    my @p = ();
    foreach my $f (qw/pref query/) {
        push(@p, $f => $p{$f}) if exists $p{$f};
    }
    
    return return_redirect(@p);
}

sub path_referer {
    my $host = $ENV{HTTP_HOST} || return;
    
    if ($ENV{HTTP_REFERER} &&
        ($ENV{HTTP_REFERER} =~ /^https?\:\/\/([^\/]+)(\/.*)$/i) &&
        (lc($1) eq lc($host))) {
        return $2;
    }
    
    return;
}
sub redirect_url {
    # Простой редирект
    my $host = $ENV{HTTP_HOST};
    if (!$host) {
        error('redirect_url: $ENV{HTTP_HOST} not defined');
        return;
    }
    if (!@_) {
        error('redirect_url: params not defined');
        return;
    }
    my $href = pref(@_);
    
    return 'http://'.$ENV{HTTP_HOST}.$href;
}
sub return_redirect {
    # Обычный редирект
    my $host = $ENV{HTTP_HOST};
    if (!$host) {
        error('return_operation: $ENV{HTTP_HOST} not defined');
        return;
    }
    
    my $href;
    if (@_) {
        my %p = @_;
        if ($p{pref}) {
            $href = pref(ref($p{pref}) eq 'ARRAY' ? @{ $p{pref} } : $p{pref});
        }
        else {
            $href = path_referer();
            debug('return_operation: redirect to back %s', $href);
        }
        if (defined(my $q = $p{query})) {
            if (ref($q) eq 'ARRAY') {
                $href .= '?' . Clib::Web::Param::data2url(@$q);
            }
            elsif (ref($q) eq 'HASH') {
                $href .= '?' . Clib::Web::Param::data2url(%$q);
            }
            elsif (!ref($q)) {
                $href .= '?'.$q;
            }
        }
        debug('return_redirect: to %s', $href);
    }
    elsif (my $path = path_referer()) {
        $href = $path;
        debug('return_redirect: to back %s', $path);
    }
    else {
        error('return_redirect: to back with wrong HTTP_REFERER: %s', $ENV{HTTP_REFERER});
        return;
    }
    
    return '', 302, Clib::Web::Param::cookiebuild(), Location => "http://".$ENV{HTTP_HOST}.$href;
}

sub return_file {
    my $file = shift();
    if ($file eq 'rdenied') {
        return '', '403 Permission denied';
    }
    elsif ($file eq 'notfound') {
        return '', '404 Not Found';
    }
    
    my $fh;
    if (!open($fh, $file)) {
        error('ReturnFile(%s): %s', $file, $!);
        return '', '404 Not Found';
    }
    
    my @hdr = ();
    if (@_ && (my $mime = shift)) {
        push @hdr, 'Content-type' => $mime;
    }
    elsif (($file =~ /\.([^.]+)$/) && ($mime = c(extMime => lc($1)))) {
        push @hdr, 'Content-type' => $mime;
    }
    if (@_ && (my $fname = shift)) {
        push @hdr, 'Content-Disposition' => "attachment; filename=".$fname;
    }
    
    return sub { local $/ = undef; return <$fh>; }, '', @hdr;
}

sub menu {
    my $mt = { list => [] };
    return
        grep { $_->{is_item} || @{ $_->{list} } }
        map {
            if (ref($_) eq 'ARRAY') {
                my ($title, $rcheck, $pref, @args) = @$_;
                my $fadd = ref($args[0]) eq 'CODE' ? shift(@args) : undef;
                my @m;
                if (rchk($rcheck)) {
                    if ($fadd) {
                        my $fres = $fadd->();
                        $title .= sprintf(' (%s)', $fres) if $fres;
                    }
                    @m = { is_item => 1, title => $title, href => pref($pref, @args) };
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
        @{ c('menu') || [] };
}

sub msgcount {
    my $user = $auth{user} || return 0;
    
    return scalar sqlSrch(msg => uid => $user->{id}, readed => 0);
}

1;
