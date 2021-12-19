package CMain::Command;

use Clib::strict8;

##################################################

sub by_id {
    sqlGet(command => shift());
}

sub rinfo {
    my $cmd = shift();
    
    rchk('command_info') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($cmd && ($user->{cmdid} != $cmd->{id}))) {
        rchk('command_info_all') || return;
    }
    
    1;
}

sub redit {
    my $cmd = shift();
    
    rchk('command_edit') || return;
    
    my $user = WebMain::auth('user') || return;
    if (!$user->{cmdid} || ($cmd && ($user->{cmdid} != $cmd->{id}))) {
        rchk('command_edit_all') || return;
    }
    
    1;
}

sub _root :
        Simple
{
    rchk('command_list') || return 'rdenied';
    my $p = wparam();
    
    my @query = ();
    my @where = ();
    
    if ($p->exists('srch') && length($p->str('srch'))) {
        my $s = $p->str('srch');
        
        push @query, srch => $s;
        
        $s =~ s/([%_])/\\$1/g;
        $s =~ s/\*/%/g;
        $s =~ s/\?/_/g;
        $s = '%'.$s if $s !~ /^%/;
        $s .= '%' if $s !~ /%$/;
        #$s .= '%' if $s !~ /^(.*[^\\])?%$/;
        push @where, sqlLike(name => $s);
    }

    my ($blkid, $blok);
    if ($p->exists('blkid')) {
        $blkid = $p->int('blkid');
        
        push @query, blkid => $blkid;
        push @where, blkid => $blkid > 0 ? $blkid : 0;
        
        $blok = sqlGet(blok => $blkid);
    }
    
    my $pager = { onpage => 100 };
    my @list = sqlSrch(command => @where, $pager, sqlOrder('name'));
    
    my %blk =
        map {
            $_->{blkid} > 0 ?
                ($_->{blkid} => 1) : ()
        }
        @list;
    if (my @blkid = keys %blk) {
        %blk =
            map { ($_->{id} => $_) }
            sqlSrch(blok => id => @blkid > 1 ? [@blkid] : $blkid[0]);
        $_->{blok} = $blk{$_->{blkid}} foreach @list;
    }
    
    return
        'command_list',
        srch    => $p->str('srch'),
        qsrch   => qsrch([qw/srch blkid/], @query),
        blkid   => $blkid,
        blok    => $blok,
        list    => \@list,
        pager   => $pager;
}

sub srch :
        ReturnBlock
{
    my ($tmpl, @p) = _root();
    return
        $tmpl => 'CONTENT_result',
        @p;
}

sub info :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    my $filelogo = 'logo.site.jpg';
    my $filesize = -s ImgFile::CachPath(command => $cmd->{id}, $filelogo);
    
    my $blok = $cmd->{blkid} ?
        sqlGet(blok => $cmd->{blkid}) :
        undef;
    
    my @ausweis_list =
        sqlSrch(
            ausweis =>
            cmdid   => $cmd->{id},
            blocked => 0,
            sqlOrder('nick')
        );
    
    my @ausweis_blocked =
        sqlSrch(
            ausweis =>
            cmdid   => $cmd->{id},
            blocked => 1,
            sqlOrder('nick')
        );
    
    # Ник для preedit-записей
    my $prenick = sub {
        if (my @precreate = grep { $_->{op} eq 'C' } @_) {
            # Для создаваемых аусов ник берём из preedit_field
            my %nick =
                map { ($_->{eid} => $_->{value}) }
                sqlSrch(
                    preedit_field =>
                    eid     => [map { $_->{id} } @precreate],
                    param   => 'nick',
                );
            $_->{nick} = $nick{ $_->{id} } foreach @precreate;
        }
        if (my @preedit = grep { $_->{op} eq 'E' } @_) {
            # для редактируемых - они скорее всего не из нашей команды,
            # раз есть поле cmdid, и их ники надо взять из аусов
            my %nick =
                map { ($_->{id} => $_->{nick}) }
                sqlSrch(ausweis => id => [map { $_->{recid} } @preedit]);
            $_->{nick} = $nick{ $_->{recid} } foreach @preedit;
        }
    };
    
    # аусы, ожидающие добавление или перенос в нашу команду:
    # тут действуем по изменению поля cmdid, указанного в preedit_field
    my @ausweis_preedit =
        map { $_->{preedit} }
        sqlQueryList(
            'SELECT `preedit`.* FROM `preedit`, `preedit_field` ' .
            'WHERE `preedit_field`.`eid`=`preedit`.`id` ' .
                'AND `preedit`.`tbl`=\'Ausweis\' ' .
                'AND `preedit`.`modered`=0 ' .
                'AND `preedit`.`uid`=? ' .
                'AND `preedit_field`.`param`=\'cmdid\' ' .
                'AND `preedit_field`.`value`=?',
            (WebMain::auth('user')||{})->{id},
            $cmd->{id}
        );
    $prenick->(@ausweis_preedit);
    
    # Аусы, прошедшие модерацию,
    # Но надо бы переделать, чтобы тут отображались все редактируемые аусы, имеющие отношение
    # к нашей команде
    # Для этого надо добавить поля cmdid и cmdold(на случай переноса в другую команду),
    # корректно их заполнять, и запрашивать preedit уже по этим полям
    my @history_my =
        map { $_->{preedit} }
        sqlQueryList(
            'SELECT `preedit`.* ' .
            'FROM `preedit` ' .
            'LEFT JOIN `preedit_field` ON `preedit_field`.`eid`=`preedit`.`id` AND `preedit_field`.`param`=\'cmdid\' ' .
            'LEFT JOIN `ausweis` ON `ausweis`.`id`=`preedit`.`recid` ' .
            'WHERE `preedit`.`tbl`=\'Ausweis\' ' .
                'AND `preedit`.`modered`!=0 ' .
                'AND `preedit`.`visibled`=1 ' .
                'AND `preedit`.`dtadd`>DATE_SUB(NOW(), INTERVAL 30 DAY) ' .
                'AND (`preedit_field`.`value`=? OR `preedit_field`.`old`=? OR `ausweis`.`cmdid`=?) ' .
            'ORDER BY `preedit`.`id`',
            $cmd->{id}, $cmd->{id}, $cmd->{id}
        );
    $prenick->(@history_my);
    
    my @account_list =
        sqlSrch(user_list => cmdid => $cmd->{id}, sqlOrder('login'));
    my %grp =
        map { $_->{gid} > 0 ? ($_->{gid} => 1) : () }
        @account_list;
    if (my @gid = keys %grp) {
        %grp =
            map { ($_->{id} => $_) }
            sqlSrch(user_group => id => \@gid);
        $_->{group} = $grp{ $_->{gid} }
            foreach @account_list;
    }
    
    return
        'command_info',
        cmd             => $cmd,
        file_logo       => $filelogo,
        file_logo_size  => $filesize,
        blok            => $blok,
        
        ausweis_list    => \@ausweis_list,
        ausweis_preedit => \@ausweis_preedit,
        ausweis_blocked => \@ausweis_blocked,
        
        account_list    => \@account_list,
        history_my      => \@history_my,
}

sub my :
        Simple
{
    my $user = WebMain::auth('user') || return 'rdenied';
    my $cmdid = $user->{cmdid} || return 'notfound';
    my $cmd = by_id($cmdid) || return 'notfound';
    
    return info($cmd);
}

sub history :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    my $blok = $cmd->{blkid} ?
        sqlGet(blok => $cmd->{blkid}) :
        undef;
    
    # id затрагиваемых аусвайсов
    my %ausid = 
        map { ($_->{id} => $_) }
        sqlSrch(ausweis => cmdid=>$cmd->{id} );
    
    # Основной список изменений
    my @list;
    if (%ausid) {
        @list = sqlSrch(preedit => tbl=>'Ausweis', recid=>[keys %ausid], sqlOrder('id'));
    }
    
    # Изменённые поля
    my %eid = map { ($_->{id} => ($_->{field_list} = [])) } @list;
    if (%eid) {
        push( @{ $eid{$_->{eid}} }, $_)
            foreach
                sqlSrch(preedit_field => eid => [keys %eid], sqlOrder('param'));
    }
    
    # Пользователи, делавшие изменения
    my %user = map { ($_->{uid} => 1) } @list;
    if (%user) {
        %user =
            map { ($_->{id} => $_) }
            sqlSrch(user_list => id => [keys %user]);
    }
    
    # Распределяем поля
    foreach my $p (@list) {
        $p->{user} = $user{ $p->{uid} };
        $p->{ausweis} = $ausid{ $p->{recid} };
    }
    
    return
        'command_history',
        cmd     => $cmd,
        blok    => $blok,
        list    => \@list,
}


sub event :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    my $blok = $cmd->{blkid} ?
        sqlGet(blok => $cmd->{blkid}) :
        undef;
    
    my @event =  sqlAll(event => '-date');
    
    # Распределение мероприятий по годам
    my %year = ();
    my @year;
    my $hidden = 0;
    foreach my $ev (@event) {
        my ($year) = ($ev->{date} =~ /^(\d{4})\-/);
        $year ||= '-';
        my $y = $year{$year};
        if (!$y) {
            $y = ($year{$year} = { year => $year, list => [], hidden => $hidden++ });
            push @year, $y;
        }
        push @{ $y->{list} }, $ev;
    }
    
    # Смотрим все аусы, участвовавшие под нашей командой
    my @evaus =
        sqlSrch(event_ausweis => cmdid => $cmd->{id}, sqlOrder('dtadd'));
    my %aus = map { ($_->{ausid} => 1) } @evaus;
    if (%aus) {
        %aus =
            map { ($_->{id} => $_) }
            sqlSrch(ausweis => id => [keys %aus]);
    }
    # Если аус сейчас в другой команде
    my %cmd =
        map { $_->{cmdid} != $cmd->{id} ? ($_->{cmdid} => 1) : () }
        values %aus;
    if (%cmd) {
        %cmd =
            map { ($_->{id} => $_) }
            sqlSrch(command => id => [keys %cmd]);
    }
    $cmd{ $cmd->{id} } = $cmd;
    
    # Распределяем аусвайсы по мероприятиям
    my %ev = map { ($_->{id} => $_) } @event;
    $_->{ausweis_list} = [] foreach @event;
    foreach my $eva (@evaus) {
        my $ev = $ev{ $eva->{evid} } || next;
        my $aus = $aus{ $eva->{ausid} } || next;
        $aus->{command} = $cmd{ $aus->{cmdid} };
        $aus->{event} = $eva;
        push @{ $ev->{ausweis_list} }, $aus;
    }
    
    return
        'command_event',
        cmd         => $cmd,
        blok        => $blok,
        event_list  => \@event,
        year_list   => \@year,
}


sub edit :
        ParamCodeUInt(\&by_id)
{
    my $cmd = shift();
    
    redit($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    editable() || return 'readonly';
    
    my @blok = sqlAll(blok => 'name');
    
    return
        'command_edit',
        cmd         => $cmd,
        form($cmd),
        blok_list   => \@blok;
}

sub file :
        ParamCodeUInt(\&by_id)
        ParamRegexp('[a-zA-Z\d\.\-]+')
        ParamEnd # ссылку будет завершать не имя функции "file", а само имя файла из аргументов
        ReturnFile
{
    my $cmd = shift();
    
    rinfo($cmd) || return 'rdenied';
    $cmd || return 'notfound';
    
    return ImgFile::CachPath(command => $cmd->{id}, shift());
}


sub adding :
        Simple
{
    rchk('command_edit_all') || return 'rdenied';
    editable() || return 'readonly';
    
    my @blok = sqlAll(blok => 'name');
    
    return
        'command_add',
        form(qw/name blkid login pass/),
        blok_list   => \@blok;
}

# Загрузка логотипа
sub _logo_load {
    my $cmdid = shift();
    defined($_[0]) || return 1;
    
    my $p = wparam();
    my $ext = $p->str('photo') =~ /\.([a-zA-Z0-9]{1,5})$/ ? lc($1) : 'jpg';
    my $fname = ImgFile::Save($_[0], [command => $cmdid], logo => orig => $ext)
        || return;
    
    sqlUpd(
        command => $cmdid,
        regen   => ImgFile::RegenBit('logo'),
        photo   => $fname
    ) || return;
    
    return 1;
}

sub add :
        ReturnOperation
{
    rchk('command_edit_all') || return err => 'rdenied';
    editable() || return err => 'readonly';
    
    my $logo;
    my $p = wparam(file => { photo => \$logo });
    my %err = ();
    my @new = ();
    my @adm = ();
    
    # Проверка данных
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push @new, name => $name;
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
        elsif (sqlSrch(command => name => $name)) {
            $err{name} = 'cmdexists';
        }
    }
    else {
        $err{name} = 'nospec';
    }

    if ((my $blkid = $p->uint('blkid')) != 0) {
        push @new, blkid => $blkid;
        if (!sqlGet(blok => $blkid)) {
            $err{blkid} = 'blkunknown';
        }
    }
    
    if ((my $login = $p->str('login')) ne '') {
        my $gid = c('command_gid');
        push @adm,
            login   => $login,
            gid     => $gid,
            rights  => Clib::Rights::GROUP x 128;
        if ($login !~ /^[a-zA-Z_0-9\-а-яА-Я]+$/) {
            $err{login} = 'format';
        }
        elsif (sqlSrch(user_list => login => $login)) {
            $err{login} = 'loginused';
        }
        elsif (!$gid || !sqlGet(user_group => $gid)) {
            $err{login} = 'grpfail';
        }
    }
    
    if (@adm) {
        if ($p->exists('pass')) {
            my $pass = $p->raw('pass');
            $pass = '' if !defined($pass);
            push @adm, password => [PASSWORD => $pass];
        
            if ($pass eq '') {
                $err{pass} = 'empty';
            }
        }
        else {
            $err{password} = 'nospec';
        }
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => 'command/adding';
    }
    
    # Сохраняем
    my $cmdid = sqlAdd(command => @new)
        || return
            err  => 'db',
            ferr => \%err,
            pref => 'command/adding';
    
    # Создаем аккаунт
    if (@adm) {
        push @adm, cmdid => $cmdid;
        my $uid = sqlAdd(user_list => @adm)
            || return
                err  => 'db',
                pref => ['command/edit', $cmdid];
    }
    
    # Загрузка логотипа
    _logo_load($cmdid, $logo)
        || return
            err  => 'imgload',
            pref => ['command/edit', $cmdid];
        
    return
        ok => 1,
        pref => ['command/info', $cmdid];
}

sub set :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $cmd = shift();
    
    redit($cmd) || return err => 'rdenied';
    $cmd || return err => 'notfound';
    editable() || return err => 'readonly';
    
    my $logo;
    my $p = wparam(file => { photo => \$logo });
    my %err = ();
    my @upd = ();
    
    # Проверка данных
    if ($p->exists('name')) {
        my $name = $p->str('name');
        push(@upd, name => $name) if $name ne $cmd->{name};
        
        if ($name eq '') {
            $err{name} = 'empty';
        }
        elsif (sqlSrch(command => name => $name, sqlNotEq(id => $cmd->{id}))) {
            $err{name} = 'cmdexists';
        }
    }
    
    if ((my $blkid = $p->uint('blkid')) != 0) {
        push(@upd, blkid => $blkid) if $blkid ne $cmd->{blkid};
        if (!sqlGet(blok => $blkid)) {
            $err{blkid} = 'blkunknown';
        }
    }
    
    # Ошибки заполнения формы
    if (%err) {
        return
            ferr => \%err,
            pref => ['command/edit' => $cmd->{id}];
    }
    
    # Надо ли, что сохранять
    if (@upd) {
        # Сохраняем
        sqlUpd(command => $cmd->{id}, @upd)
            || return
                err  => 'db',
                ferr => \%err,
                pref => ['command/edit' => $cmd->{id}];
    }
    elsif (!defined($logo)) {
        return err => 'nochange', pref => ['command/edit' => $cmd->{id}];
    }
    
    # Загрузка логотипа
    _logo_load($cmd->{id}, $logo)
        || return
            err  => 'imgload',
            pref => ['command/edit', $cmd->{id}];
    

    # обновляем поле blkid в аусах
    my %upd = @upd;
    if (exists $upd{blkid}) {
        foreach my $aus (sqlSrch(ausweis => cmdid => $cmd->{id})) {
            sqlUpd(ausweis => $aus->{id}, blkid => $upd{blkid}) || last;
        }
    }
        
    return
        ok => 1,
        pref => ['command/info' => $cmd->{id}];
}

sub logo :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $cmd = shift();
    
    rchk('command_logo') || return err => 'rdenied';
    
    my $user = WebMain::auth('user') || return err => 'rdenied';
    if (!$user->{cmdid} || ($cmd && ($user->{cmdid} != $cmd->{id}))) {
        rchk('command_logo_all') || return err => 'rdenied';
    }
    
    $cmd || return err => 'notfound';
    
    my $logo;
    my $p = wparam(file => { photo => \$logo });
    
    # Загрузка логотипа
    _logo_load($cmd->{id}, $logo)
        || return
            err  => 'imgload',
            pref => ['command/info', $cmd->{id}];
        
    return
        ok => 1,
        pref => ['command/info' => $cmd->{id}];
}

sub del :
        ParamCodeUInt(\&by_id)
        ReturnOperation
{
    my $cmd = shift();
    
    rchk('command_edit_all') || return err => 'rdenied';
    editable() || return err => 'readonly';
    $cmd || return err => 'notfound';
    
    if (sqlSrch(ausweis => cmdid => $cmd->{id}, sqlLimit(1))) {
        return
            err  => c(state => 'cmdnoempty'),
            pref => '';
            
    }
    
    sqlDel(command => $cmd->{id})
        || return
            err  => 'db',
            pref => '';
        
    return
        ok => 1,
        pref => 'command';
}
    
1;
